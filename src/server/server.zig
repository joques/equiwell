const std = @import("std");
const Config = @import("../config/config.zig").Config;
const Router = @import("router.zig").Router;
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Middleware = @import("middleware.zig").Middleware;
const Logger = @import("../observability/logger.zig").Logger;
const Metrics = @import("../observability/metrics.zig").Metrics;

/// Centralized hard limit on maximum allowed HTTP request body size (10 MB).
/// Prevents unauthenticated memory exhaustion and Out-Of-Memory (OOM) denial-of-service attacks.
pub const MAX_BODY_SIZE: usize = 10 * 1024 * 1024;

/// Default socket read/write timeout in milliseconds to mitigate Slowloris attacks.
pub const DEFAULT_SOCKET_TIMEOUT_MS: u32 = 5000;

pub const SOCKET = usize;
pub const INVALID_SOCKET: SOCKET = ~@as(SOCKET, 0);
pub const SOCKET_ERROR: i32 = -1;
pub const SOL_SOCKET: i32 = 0xffff;
pub const SO_RCVTIMEO: i32 = 0x1006;
pub const SO_SNDTIMEO: i32 = 0x1005;

const WSADATA = extern struct {
    wVersion: u16,
    wHighVersion: u16,
    szDescription: [257]u8,
    szSystemStatus: [129]u8,
    iMaxSockets: u16,
    iMaxUdpDg: u16,
    lpVendorInfo: ?*u8,
};

const sockaddr_in = extern struct {
    sin_family: u16 = 2, // AF_INET
    sin_port: u16,
    sin_addr: u32,
    sin_zero: [8]u8 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
};

extern "ws2_32" fn WSAStartup(wVersionRequired: u16, lpWSAData: *WSADATA) callconv(std.builtin.CallingConvention.winapi) i32;
extern "ws2_32" fn WSACleanup() callconv(std.builtin.CallingConvention.winapi) i32;
extern "ws2_32" fn socket(af: i32, type_: i32, protocol: i32) callconv(std.builtin.CallingConvention.winapi) SOCKET;
extern "ws2_32" fn bind(s: SOCKET, name: *const anyopaque, namelen: i32) callconv(std.builtin.CallingConvention.winapi) i32;
extern "ws2_32" fn listen(s: SOCKET, backlog: i32) callconv(std.builtin.CallingConvention.winapi) i32;
extern "ws2_32" fn accept(s: SOCKET, addr: ?*anyopaque, addrlen: ?*i32) callconv(std.builtin.CallingConvention.winapi) SOCKET;
extern "ws2_32" fn recv(s: SOCKET, buf: [*]u8, len: i32, flags: i32) callconv(std.builtin.CallingConvention.winapi) i32;
extern "ws2_32" fn shutdown(s: SOCKET, how: i32) callconv(std.builtin.CallingConvention.winapi) i32;
extern "ws2_32" fn closesocket(s: SOCKET) callconv(std.builtin.CallingConvention.winapi) i32;
extern "ws2_32" fn setsockopt(s: SOCKET, level: i32, optname: i32, optval: [*]const u8, optlen: i32) callconv(std.builtin.CallingConvention.winapi) i32;

extern "kernel32" fn CreateSemaphoreW(lpAttributes: ?*anyopaque, lInitialCount: i32, lMaximumCount: i32, lpName: ?[*:0]const u16) callconv(std.builtin.CallingConvention.winapi) ?*anyopaque;
extern "kernel32" fn WaitForSingleObject(hHandle: *anyopaque, dwMilliseconds: u32) callconv(std.builtin.CallingConvention.winapi) u32;
extern "kernel32" fn ReleaseSemaphore(hSemaphore: *anyopaque, lReleaseCount: i32, lpPreviousCount: ?*i32) callconv(std.builtin.CallingConvention.winapi) i32;
extern "kernel32" fn CloseHandle(hObject: *anyopaque) callconv(std.builtin.CallingConvention.winapi) i32;

/// Atomic spinlock mutex.
pub const SpinMutex = struct {
    state: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn lock(self: *SpinMutex) void {
        while (self.state.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *SpinMutex) void {
        self.state.store(false, .release);
    }
};

/// Bounded concurrent worker pool preventing thread exhaustion and thread-bombing.
pub const WorkerPool = struct {
    pub const QUEUE_CAPACITY = 256;

    mutex: SpinMutex = .{},
    sem: *anyopaque,
    queue: [QUEUE_CAPACITY]SOCKET = undefined,
    head: usize = 0,
    tail: usize = 0,
    count: usize = 0,
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
    threads: []std.Thread,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, num_workers: usize, server: *Server) !*WorkerPool {
        const pool = try allocator.create(WorkerPool);
        pool.allocator = allocator;
        pool.mutex = .{};
        pool.sem = CreateSemaphoreW(null, 0, QUEUE_CAPACITY, null) orelse return error.SemaphoreCreateFailed;
        pool.head = 0;
        pool.tail = 0;
        pool.count = 0;
        pool.running.store(true, .seq_cst);

        const actual_workers = @max(1, @min(num_workers, 64));
        pool.threads = try allocator.alloc(std.Thread, actual_workers);

        for (pool.threads) |*t| {
            t.* = try std.Thread.spawn(.{}, workerThreadFn, .{ pool, server });
        }
        return pool;
    }

    pub fn post(self: *WorkerPool, sock: SOCKET) bool {
        self.mutex.lock();
        if (self.count >= QUEUE_CAPACITY) {
            self.mutex.unlock();
            return false;
        }

        self.queue[self.tail] = sock;
        self.tail = (self.tail + 1) % QUEUE_CAPACITY;
        self.count += 1;
        self.mutex.unlock();

        _ = ReleaseSemaphore(self.sem, 1, null);
        return true;
    }

    fn workerThreadFn(self: *WorkerPool, server: *Server) void {
        while (self.running.load(.monotonic)) {
            const wait_res = WaitForSingleObject(self.sem, 250);
            if (wait_res == 0) {
                var sock: SOCKET = INVALID_SOCKET;
                self.mutex.lock();
                if (self.count > 0) {
                    sock = self.queue[self.head];
                    self.head = (self.head + 1) % QUEUE_CAPACITY;
                    self.count -= 1;
                }
                self.mutex.unlock();

                if (sock != INVALID_SOCKET) {
                    server.processSocket(sock);
                }
            }
        }
    }

    pub fn deinit(self: *WorkerPool) void {
        self.running.store(false, .seq_cst);
        for (self.threads) |t| {
            t.join();
        }
        _ = CloseHandle(self.sem);
        self.allocator.free(self.threads);
        self.allocator.destroy(self);
    }
};

/// Enterprise TCP Server managing connections, thread execution, and socket IO.
pub const Server = struct {
    config: Config,
    router: *Router,
    middleware: Middleware,
    logger: Logger,
    metrics: *Metrics,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        config: Config,
        router: *Router,
        middleware: Middleware,
        logger: Logger,
        metrics: *Metrics,
    ) Server {
        return .{
            .allocator = allocator,
            .config = config,
            .router = router,
            .middleware = middleware,
            .logger = logger,
            .metrics = metrics,
        };
    }

    /// Configures receive and send socket timeouts to drop stalled connections cleanly.
    pub fn configureClientSocket(sock: SOCKET, timeout_ms: u32) !void {
        const timeout_bytes: [4]u8 = @bitCast(timeout_ms);
        const rcv_res = setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout_bytes, @sizeOf(u32));
        if (rcv_res == SOCKET_ERROR) return error.SocketOptionFailed;
        const snd_res = setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout_bytes, @sizeOf(u32));
        if (snd_res == SOCKET_ERROR) return error.SocketOptionFailed;
    }

    /// Starts the TCP socket listener and enters the accept event loop.
    pub fn start(self: *Server) !void {
        var wsaData: WSADATA = undefined;
        const wsa_res = WSAStartup(0x0202, &wsaData);
        if (wsa_res != 0) {
            self.logger.err("Failed to initialize Winsock: {d}", .{wsa_res});
            return error.WinsockInitFailed;
        }
        defer _ = WSACleanup();

        const server_socket = socket(2, 1, 6); // AF_INET=2, SOCK_STREAM=1, IPPROTO_TCP=6
        if (server_socket == INVALID_SOCKET) {
            self.logger.err("Failed to create master TCP socket.", .{});
            return error.SocketCreateFailed;
        }
        defer _ = closesocket(server_socket);

        var server_addr: sockaddr_in = .{
            .sin_family = 2,
            .sin_port = std.mem.nativeToBig(u16, self.config.port),
            .sin_addr = 0x0100007F, // 127.0.0.1 in network byte order
            .sin_zero = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
        };

        const bind_res = bind(server_socket, @ptrCast(&server_addr), @sizeOf(sockaddr_in));
        if (bind_res == SOCKET_ERROR) {
            self.logger.err("Failed to bind socket to port {d}.", .{self.config.port});
            return error.SocketBindFailed;
        }

        const listen_res = listen(server_socket, 128);
        if (listen_res == SOCKET_ERROR) {
            self.logger.err("Failed to listen on socket.", .{});
            return error.SocketListenFailed;
        }

        std.debug.print("\n=======================================================\n", .{});
        std.debug.print("  EquiWell Enterprise Backend (Zig v0.17)\n", .{});
        std.debug.print("  Listening on http://{s}:{d}\n", .{ self.config.host, self.config.port });
        std.debug.print("  API Base: /api/v1 (Canonical) + Legacy Root\n", .{});
        std.debug.print("  Worker Pool: {d} Threads (Bounded Capacity {d})\n", .{ self.config.worker_pool_size, WorkerPool.QUEUE_CAPACITY });
        std.debug.print("  Max Request Body: {d} MB | Socket Timeout: {d}ms\n", .{ self.config.max_body_size / (1024 * 1024), self.config.socket_timeout_ms });
        std.debug.print("  Architecture: Modular Layered Clean Enterprise\n", .{});
        std.debug.print("=======================================================\n\n", .{});

        // Initialize bounded worker pool
        const pool = try WorkerPool.init(self.allocator, self.config.worker_pool_size, self);
        defer pool.deinit();

        while (true) {
            var client_addr: sockaddr_in = undefined;
            var client_addr_len: i32 = @sizeOf(sockaddr_in);
            const client_socket = accept(server_socket, @ptrCast(&client_addr), &client_addr_len);
            if (client_socket == INVALID_SOCKET) {
                continue;
            }

            // Configure socket timeouts immediately to prevent Slowloris attacks
            configureClientSocket(client_socket, self.config.socket_timeout_ms) catch {
                _ = shutdown(client_socket, 1);
                _ = closesocket(client_socket);
                continue;
            };

            // Dispatch to bounded worker pool
            if (!pool.post(client_socket)) {
                // Queue saturated: record metric, apply backpressure and return 503 Service Unavailable
                self.metrics.recordQueueRejection();
                var arena = std.heap.ArenaAllocator.init(self.allocator);
                const req_allocator = arena.allocator();
                const response: Response = .{ .socket = client_socket, .allocator = req_allocator };
                response.serviceUnavailable("Server is under heavy load. Please retry shortly.") catch {};
                arena.deinit();
                _ = shutdown(client_socket, 1);
                _ = closesocket(client_socket);
            }
        }
    }

    /// Single entrypoint managing connection lifecycle with deterministic cleanup and metric recording.
    pub fn processSocket(self: *Server, client_socket: SOCKET) void {
        const start_time = self.metrics.recordRequestStart();
        var status_code: u16 = 200;
        var bytes_sent: usize = 0;
        var total_req_bytes: usize = 0;
        var is_security_rejection: bool = false;

        self.handleConnection(client_socket, &status_code, &bytes_sent, &total_req_bytes, &is_security_rejection) catch |err| {
            self.logger.err("Error processing client connection: {}", .{err});
            self.metrics.recordWorkerTaskFailed();
        };
        self.metrics.recordRequestComplete(start_time, status_code, total_req_bytes, bytes_sent, is_security_rejection);
        self.metrics.recordWorkerTaskCompleted();

        _ = shutdown(client_socket, 1);
        _ = closesocket(client_socket);
    }

    fn handleConnection(
        self: *Server,
        client_socket: SOCKET,
        status_code: *u16,
        bytes_sent: *usize,
        total_req_bytes: *usize,
        is_security_rejection: *bool,
    ) !void {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const req_allocator = arena.allocator();

        var buffer: [8192]u8 = undefined;
        var total_read: usize = 0;
        var header_end_pos: ?usize = null;
        var content_length: usize = 0;

        while (total_read < buffer.len) {
            const bytes_recv = recv(client_socket, buffer[total_read..].ptr, @intCast(buffer.len - total_read), 0);
            if (bytes_recv <= 0) break;
            total_read += @intCast(bytes_recv);

            if (std.mem.indexOf(u8, buffer[0..total_read], "\r\n\r\n")) |pos| {
                header_end_pos = pos;
                break;
            }
        }
        total_req_bytes.* = total_read;

        if (header_end_pos == null) {
            // Buffer filled to 8KB without finding \r\n\r\n (Oversized headers)
            if (total_read >= buffer.len) {
                is_security_rejection.* = true;
                const response: Response = .{
                    .socket = client_socket,
                    .allocator = req_allocator,
                    .status_code_ptr = status_code,
                    .bytes_sent_ptr = bytes_sent,
                };
                try response.requestHeaderFieldsTooLarge("Request headers exceed maximum size limit of 8192 bytes.");
            }
            return;
        }

        const header_end = header_end_pos.?;
        const raw_headers = buffer[0..header_end];

        // Standards-compliant case-insensitive header scanning and request-smuggling defense
        var cl_count: usize = 0;
        var header_lines = std.mem.splitSequence(u8, raw_headers, "\r\n");
        while (header_lines.next()) |line| {
            if (line.len >= 15 and std.ascii.startsWithIgnoreCase(line[0..15], "content-length:")) {
                const cl_val = std.mem.trim(u8, line[15..], " \t");
                if (cl_val.len == 0) {
                    is_security_rejection.* = true;
                    const response: Response = .{
                        .socket = client_socket,
                        .allocator = req_allocator,
                        .status_code_ptr = status_code,
                        .bytes_sent_ptr = bytes_sent,
                    };
                    return try response.badRequest("Empty Content-Length header.");
                }

                // Strictly validate numeric ASCII decimal characters [0-9]
                for (cl_val) |c| {
                    if (c < '0' or c > '9') {
                        is_security_rejection.* = true;
                        const response: Response = .{
                            .socket = client_socket,
                            .allocator = req_allocator,
                            .status_code_ptr = status_code,
                            .bytes_sent_ptr = bytes_sent,
                        };
                        return try response.badRequest("Invalid Content-Length header format.");
                    }
                }

                const parsed_cl = std.fmt.parseInt(usize, cl_val, 10) catch {
                    is_security_rejection.* = true;
                    const response: Response = .{
                        .socket = client_socket,
                        .allocator = req_allocator,
                        .status_code_ptr = status_code,
                        .bytes_sent_ptr = bytes_sent,
                    };
                    return try response.badRequest("Content-Length exceeds numeric bounds.");
                };

                // Reject conflicting duplicate Content-Length headers (request smuggling mitigation)
                if (cl_count > 0 and parsed_cl != content_length) {
                    is_security_rejection.* = true;
                    const response: Response = .{
                        .socket = client_socket,
                        .allocator = req_allocator,
                        .status_code_ptr = status_code,
                        .bytes_sent_ptr = bytes_sent,
                    };
                    return try response.badRequest("Conflicting duplicate Content-Length headers.");
                }

                content_length = parsed_cl;
                cl_count += 1;
            }
        }

        // Enforce hard upper bound on body size (10MB) before any heap allocation
        if (content_length > self.config.max_body_size) {
            is_security_rejection.* = true;
            const response: Response = .{
                .socket = client_socket,
                .allocator = req_allocator,
                .status_code_ptr = status_code,
                .bytes_sent_ptr = bytes_sent,
            };
            return try response.payloadTooLarge("Request body exceeds maximum allowed size of 10MB.");
        }

        const body_start = header_end + 4;
        var current_body_len = total_read - body_start;

        var body_buf = try req_allocator.alloc(u8, content_length);
        if (current_body_len > 0) {
            const copy_len = @min(current_body_len, content_length);
            @memcpy(body_buf[0..copy_len], buffer[body_start .. body_start + copy_len]);
        }

        while (current_body_len < content_length) {
            const bytes_recv = recv(client_socket, body_buf[current_body_len..].ptr, @intCast(content_length - current_body_len), 0);
            if (bytes_recv <= 0) break;
            current_body_len += @intCast(bytes_recv);
            total_req_bytes.* += @intCast(bytes_recv);
        }

        var lines = std.mem.splitSequence(u8, raw_headers, "\r\n");
        const request_line = lines.next() orelse return;
        var req_parts = std.mem.splitScalar(u8, request_line, ' ');
        const method = req_parts.next() orelse return;
        const full_url = req_parts.next() orelse return;

        const path = if (std.mem.indexOf(u8, full_url, "?")) |q| full_url[0..q] else full_url;

        const response: Response = .{
            .socket = client_socket,
            .allocator = req_allocator,
            .status_code_ptr = status_code,
            .bytes_sent_ptr = bytes_sent,
        };

        if (std.mem.eql(u8, method, "OPTIONS")) {
            return try response.noContent();
        }

        var request: Request = .{
            .method = method,
            .path = path,
            .raw_path = path,
            .full_url = full_url,
            .headers = raw_headers,
            .body = body_buf,
            .allocator = req_allocator,
        };

        // Execute Middleware Chain (Authentication, Request Context)
        self.middleware.authenticate(&request);

        // Dispatch via Router
        try self.router.dispatch(&request, &response);
    }
};
