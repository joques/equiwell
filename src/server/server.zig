const std = @import("std");
const Config = @import("../config/config.zig").Config;
const Router = @import("router.zig").Router;
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Middleware = @import("middleware.zig").Middleware;
const Logger = @import("../observability/logger.zig").Logger;
const Metrics = @import("../observability/metrics.zig").Metrics;

pub const SOCKET = usize;
pub const INVALID_SOCKET: SOCKET = ~@as(SOCKET, 0);
pub const SOCKET_ERROR: i32 = -1;

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
        std.debug.print("  Architecture: Modular Layered Clean Enterprise\n", .{});
        std.debug.print("=======================================================\n\n", .{});

        while (true) {
            var client_addr: sockaddr_in = undefined;
            var client_addr_len: i32 = @sizeOf(sockaddr_in);
            const client_socket = accept(server_socket, @ptrCast(&client_addr), &client_addr_len);
            if (client_socket == INVALID_SOCKET) {
                continue;
            }

            self.handleConnection(client_socket) catch |err| {
                self.logger.err("Error processing client connection: {}", .{err});
            };

            _ = shutdown(client_socket, 1);
            _ = closesocket(client_socket);
        }
    }

    fn handleConnection(self: *Server, client_socket: SOCKET) !void {
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

        if (header_end_pos == null) return;
        const header_end = header_end_pos.?;
        const raw_headers = buffer[0..header_end];

        if (std.mem.indexOf(u8, raw_headers, "Content-Length: ")) |cl_pos| {
            const after_cl = raw_headers[cl_pos + 16 ..];
            if (std.mem.indexOf(u8, after_cl, "\r\n")) |cl_end| {
                const cl_str = std.mem.trim(u8, after_cl[0..cl_end], " \t");
                content_length = std.fmt.parseInt(usize, cl_str, 10) catch 0;
            }
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
