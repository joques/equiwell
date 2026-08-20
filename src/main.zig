const std = @import("std");
const config = @import("config.zig");
const DataStore = @import("db/store.zig").DataStore;
const jwt = @import("auth/jwt.zig");
const rbac = @import("auth/rbac.zig");
const http_util = @import("utils/http_util.zig");

// Route Handlers
const user_routes = @import("routes/user_routes.zig");
const dashboard_routes = @import("routes/dashboard_routes.zig");
const borehole_routes = @import("routes/borehole_routes.zig");
const health_routes = @import("routes/health_routes.zig");
const maintenance_routes = @import("routes/maintenance_routes.zig");
const allocation_routes = @import("routes/allocation_routes.zig");
const logistics_routes = @import("routes/logistics_routes.zig");
const ai_routes = @import("routes/ai_routes.zig");

// Winsock Type Definitions & Extern API Declarations
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
extern "ws2_32" fn send(s: SOCKET, buf: [*]const u8, len: i32, flags: i32) callconv(std.builtin.CallingConvention.winapi) i32;
extern "ws2_32" fn shutdown(s: SOCKET, how: i32) callconv(std.builtin.CallingConvention.winapi) i32;
extern "ws2_32" fn closesocket(s: SOCKET) callconv(std.builtin.CallingConvention.winapi) i32;

/// Application Entry Point
/// Initializes Windows Sockets (WSAStartup), creates TCP listener socket on port 8080,
/// initializes the in-memory DataStore, and enters the client request dispatch loop.
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Initialize Windows Sockets Subsystem
    var wsaData: WSADATA = undefined;
    const wsa_res = WSAStartup(0x0202, &wsaData);
    if (wsa_res != 0) {
        std.debug.print("Failed to initialize Winsock: error {d}\n", .{wsa_res});
        return;
    }
    defer _ = WSACleanup();

    // 2. Initialize In-Memory Data Store with Kunene Region Fixtures
    const store = try DataStore.init(allocator);
    defer store.deinit();

    // 3. Create TCP Master Socket (AF_INET=2, SOCK_STREAM=1, IPPROTO_TCP=6)
    const server_socket = socket(2, 1, 6);
    if (server_socket == INVALID_SOCKET) {
        std.debug.print("Failed to create master TCP socket.\n", .{});
        return;
    }
    defer _ = closesocket(server_socket);

    // 4. Bind Socket to Host Interface (127.0.0.1:8080)
    var server_addr: sockaddr_in = .{
        .sin_family = 2,
        .sin_port = std.mem.nativeToBig(u16, config.global_config.port),
        .sin_addr = 0x0100007F, // 127.0.0.1 in network byte order
        .sin_zero = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };

    const bind_res = bind(server_socket, @ptrCast(&server_addr), @sizeOf(sockaddr_in));
    if (bind_res == SOCKET_ERROR) {
        std.debug.print("Failed to bind socket to port {d}.\n", .{config.global_config.port});
        return;
    }

    // 5. Listen for Incoming Client Connections
    const listen_res = listen(server_socket, 128);
    if (listen_res == SOCKET_ERROR) {
        std.debug.print("Failed to listen on socket.\n", .{});
        return;
    }

    std.debug.print("\n=======================================================\n", .{});
    std.debug.print("  EquiWell API Backend Server (Zig v0.17)\n", .{});
    std.debug.print("  Listening on http://{s}:{d}\n", .{ config.global_config.host, config.global_config.port });
    std.debug.print("  RBAC Security Model: Enabled (JWT HMAC-SHA256)\n", .{});
    std.debug.print("  Region: Kunene Region, Namibia\n", .{});
    std.debug.print("=======================================================\n\n", .{});

    // 6. Master Event / Accept Loop
    while (true) {
        var client_addr: sockaddr_in = undefined;
        var client_addr_len: i32 = @sizeOf(sockaddr_in);
        const client_socket = accept(server_socket, @ptrCast(&client_addr), &client_addr_len);
        if (client_socket == INVALID_SOCKET) {
            continue;
        }

        // Handle connection within a per-request arena allocator for zero-leak cleanup
        handleClient(allocator, store, client_socket) catch |err| {
            std.debug.print("Error handling client request: {}\n", .{err});
        };

        _ = shutdown(client_socket, 1); // SD_SEND
        _ = closesocket(client_socket);
    }
}

/// Reads HTTP request from socket, parses headers and body, verifies JWT, and dispatches to route handlers.
fn handleClient(allocator: std.mem.Allocator, store: *DataStore, client_socket: SOCKET) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const req_allocator = arena.allocator();

    var buffer: [8192]u8 = undefined;
    var total_read: usize = 0;
    var header_end_pos: ?usize = null;
    var content_length: usize = 0;

    // Read HTTP headers from TCP stream
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

    // Extract Content-Length if present
    if (std.mem.indexOf(u8, raw_headers, "Content-Length: ")) |cl_pos| {
        const after_cl = raw_headers[cl_pos + 16 ..];
        if (std.mem.indexOf(u8, after_cl, "\r\n")) |cl_end| {
            const cl_str = std.mem.trim(u8, after_cl[0..cl_end], " \t");
            content_length = std.fmt.parseInt(usize, cl_str, 10) catch 0;
        }
    }

    // Read remaining body bytes if segmented across packets
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

    const body = body_buf;

    // Parse Request Line (Method, Path)
    var lines = std.mem.splitSequence(u8, raw_headers, "\r\n");
    const request_line = lines.next() orelse return;
    var req_parts = std.mem.splitScalar(u8, request_line, ' ');
    const method = req_parts.next() orelse return;
    const full_url = req_parts.next() orelse return;

    // Path without query parameters
    const path = if (std.mem.indexOf(u8, full_url, "?")) |q| full_url[0..q] else full_url;

    // Extract Authorization Header
    var auth_header: ?[]const u8 = null;
    while (lines.next()) |line| {
        if (std.ascii.startsWithIgnoreCase(line, "authorization:")) {
            auth_header = std.mem.trim(u8, line[14..], " \t");
            break;
        }
    }

    // Authenticate JWT Token
    var current_user: ?jwt.TokenPayload = null;
    if (rbac.extractBearerToken(auth_header)) |token_str| {
        current_user = jwt.verifyToken(req_allocator, token_str);
    }

    const response: http_util.Response = .{
        .socket = client_socket,
        .allocator = req_allocator,
    };

    // Handle CORS Pre-flight Options Request
    if (std.mem.eql(u8, method, "OPTIONS")) {
        return try http_util.writeResponse(&response, 204, "No Content", "text/plain", "");
    }

    // 7. Route Request Dispatcher
    try dispatchRoute(req_allocator, store, method, path, full_url, body, current_user, &response);
}

/// Dispatches parsed HTTP request to the corresponding domain route handler.
fn dispatchRoute(
    allocator: std.mem.Allocator,
    store: *DataStore,
    method: []const u8,
    path: []const u8,
    full_url: []const u8,
    body: []const u8,
    current_user: ?jwt.TokenPayload,
    response: *const http_util.Response,
) !void {
    // ----------------------------------------------------
    // 1. DASHBOARD MODULE
    // ----------------------------------------------------
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/dashboard/summary")) {
        return try dashboard_routes.handleDashboardSummary(allocator, store, response);
    }

    // ----------------------------------------------------
    // 2. USER & AUTHENTICATION MODULE
    // ----------------------------------------------------
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/users/register")) {
        return try user_routes.handleRegister(allocator, store, body, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/users/login")) {
        return try user_routes.handleLogin(allocator, store, body, response);
    }
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/users")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try user_routes.handleListUsers(allocator, store, user, response);
    }
    if (std.mem.startsWith(u8, path, "/users/")) {
        const sub_path = path[7..];

        // PATCH /users/{id}/role
        if (std.mem.endsWith(u8, sub_path, "/role") and std.mem.eql(u8, method, "PATCH")) {
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            const user_id = sub_path[0 .. sub_path.len - 5];
            return try user_routes.handleUpdateUserRole(allocator, store, user_id, body, user, response);
        }

        const user_id = sub_path;
        if (std.mem.eql(u8, method, "GET")) {
            return try user_routes.handleGetUserById(allocator, store, user_id, response);
        }
        if (std.mem.eql(u8, method, "PUT")) {
            _ = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try user_routes.handleUpdateUser(allocator, store, user_id, body, response);
        }
        if (std.mem.eql(u8, method, "DELETE")) {
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try user_routes.handleDeleteUser(allocator, store, user_id, user, response);
        }
    }

    // ----------------------------------------------------
    // 3. BOREHOLES & SUB-RESOURCES MODULE
    // ----------------------------------------------------
    if (std.mem.eql(u8, path, "/boreholes")) {
        if (std.mem.eql(u8, method, "GET")) {
            return try borehole_routes.handleGetBoreholes(allocator, store, full_url, current_user, response);
        }
        if (std.mem.eql(u8, method, "POST")) {
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try borehole_routes.handleCreateBorehole(allocator, store, body, user, response);
        }
    }

    if (std.mem.startsWith(u8, path, "/boreholes/")) {
        const rest = path[11..];

        // Sub-resource: /boreholes/{id}/lab-tests
        if (std.mem.endsWith(u8, rest, "/lab-tests")) {
            const bh_id = rest[0 .. rest.len - 10];
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            if (std.mem.eql(u8, method, "POST")) {
                return try health_routes.handleCreateLabTest(allocator, store, bh_id, body, user, response);
            }
            if (std.mem.eql(u8, method, "GET")) {
                return try health_routes.handleGetLabTests(allocator, store, bh_id, user, response);
            }
        }

        // Sub-resource: /boreholes/{id}/usage-quotas
        if (std.mem.endsWith(u8, rest, "/usage-quotas") and std.mem.eql(u8, method, "GET")) {
            const bh_id = rest[0 .. rest.len - 13];
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try health_routes.handleGetUsageQuota(allocator, bh_id, user, response);
        }

        // Sub-resource: /boreholes/{id}/telemetry
        if (std.mem.endsWith(u8, rest, "/telemetry") and std.mem.eql(u8, method, "POST")) {
            const bh_id = rest[0 .. rest.len - 10];
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try maintenance_routes.handleIngestTelemetry(allocator, store, bh_id, body, user, response);
        }

        // Sub-resource: /boreholes/{id}/history
        if (std.mem.endsWith(u8, rest, "/history") and std.mem.eql(u8, method, "GET")) {
            const bh_id = rest[0 .. rest.len - 8];
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try maintenance_routes.handleGetYieldHistory(allocator, bh_id, user, response);
        }

        // Sub-resource: /boreholes/{id}/logistics
        if (std.mem.endsWith(u8, rest, "/logistics") and std.mem.eql(u8, method, "GET")) {
            const bh_id = rest[0 .. rest.len - 10];
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try logistics_routes.handleGetBoreholeLogistics(allocator, store, bh_id, user, response);
        }

        // Core Borehole Single Asset CRUD: /boreholes/{id}
        const bh_id = rest;
        if (std.mem.eql(u8, method, "GET")) {
            return try borehole_routes.handleGetBoreholeById(allocator, store, bh_id, response);
        }
        if (std.mem.eql(u8, method, "PUT")) {
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try borehole_routes.handleUpdateBorehole(allocator, store, bh_id, body, user, response);
        }
        if (std.mem.eql(u8, method, "PATCH")) {
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try borehole_routes.handlePatchBorehole(allocator, store, bh_id, body, user, response);
        }
        if (std.mem.eql(u8, method, "DELETE")) {
            const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
            return try borehole_routes.handleDeleteBorehole(allocator, store, bh_id, user, response);
        }
    }

    // ----------------------------------------------------
    // 4. MAINTENANCE & ALERTS MODULE
    // ----------------------------------------------------
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/maintenance-alerts")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try maintenance_routes.handleGetMaintenanceAlerts(allocator, store, user, response);
    }

    // ----------------------------------------------------
    // 5. ALLOCATION & COMMUNITY REQUESTS MODULE
    // ----------------------------------------------------
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/allocation-metrics")) {
        return try allocation_routes.handleGetAllocationMetrics(allocator, response);
    }
    if (std.mem.eql(u8, path, "/community-requests")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        if (std.mem.eql(u8, method, "GET")) {
            return try allocation_routes.handleGetCommunityRequests(allocator, store, user, response);
        }
        if (std.mem.eql(u8, method, "POST")) {
            return try allocation_routes.handleCreateCommunityRequest(allocator, store, body, user, response);
        }
    }

    // ----------------------------------------------------
    // 6. LOGISTICS & NAVIGATION ROUTING MODULE
    // ----------------------------------------------------
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/routes/calculate")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try logistics_routes.handleCalculateRoute(allocator, body, user, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/routes/google-maps-directions")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try logistics_routes.handleGoogleMapsDirections(allocator, body, user, response);
    }

    // ----------------------------------------------------
    // 7. AI SITING & HYDROGEOLOGY MODULE
    // ----------------------------------------------------
    if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/factors")) {
        return try ai_routes.handleGetFactors(allocator, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/suggestions/generate")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try ai_routes.handleGenerateSuggestion(allocator, store, body, user, response);
    }
    if (std.mem.startsWith(u8, path, "/suggestions/") and std.mem.eql(u8, method, "GET")) {
        const sug_id = path[13..];
        return try ai_routes.handleGetSuggestionById(allocator, store, sug_id, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/predict-yield")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try ai_routes.handlePredictYield(allocator, body, user, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/aquifer-depletion-risk")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try ai_routes.handleAquiferDepletionRisk(allocator, body, user, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/siting-tasks/async")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try ai_routes.handleAsyncSitingTask(allocator, body, user, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/callbacks/ai/siting-complete")) {
        return try ai_routes.handleSitingCompleteCallback(allocator, body, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/training-data/borehole-logs")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try ai_routes.handleIngestDrillingLogs(allocator, store, body, user, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/training-data/yield-maps")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try ai_routes.handleIngestYieldMaps(allocator, body, user, response);
    }
    if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/routes/terrain-feasibility")) {
        const user = current_user orelse return try http_util.sendUnauthorized(response, "Authentication token required.");
        return try ai_routes.handleTerrainFeasibility(allocator, body, user, response);
    }

    // ----------------------------------------------------
    // 8. NOT FOUND FALLBACK
    // ----------------------------------------------------
    try http_util.sendNotFound(response, "The requested endpoint route does not exist on this server.");
}
