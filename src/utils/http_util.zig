const std = @import("std");

pub const SOCKET = usize;
pub const SOCKET_ERROR: i32 = -1;

extern "ws2_32" fn send(s: SOCKET, buf: [*]const u8, len: i32, flags: i32) callconv(std.builtin.CallingConvention.winapi) i32;

/// HTTP response abstraction enabling socket writes with standardized headers and status codes.
pub const Response = struct {
    /// Native socket handle.
    socket: SOCKET,
    /// Memory allocator for assembling HTTP headers and payloads.
    allocator: std.mem.Allocator,

    /// Writes raw bytes to the client socket.
    pub fn writeAll(self: *const Response, data: []const u8) !void {
        var total_sent: usize = 0;
        while (total_sent < data.len) {
            const chunk = data[total_sent..];
            const sent = send(
                self.socket,
                chunk.ptr,
                @intCast(chunk.len),
                0,
            );
            if (sent == SOCKET_ERROR) {
                return error.SocketSendFailed;
            }
            total_sent += @intCast(sent);
        }
    }
};

/// Sends an HTTP response with the specified status code, content type, and body.
pub fn writeResponse(response: *const Response, status_code: u16, status_text: []const u8, content_type: []const u8, body: []const u8) !void {
    const header = try std.fmt.allocPrint(
        response.allocator,
        "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, Authorization\r\nConnection: close\r\n\r\n",
        .{ status_code, status_text, content_type, body.len },
    );
    defer response.allocator.free(header);

    try response.writeAll(header);
    if (body.len > 0) {
        try response.writeAll(body);
    }
}

/// Sends a `200 OK` JSON response.
pub fn sendOk(response: *const Response, json_body: []const u8) !void {
    try writeResponse(response, 200, "OK", "application/json", json_body);
}

/// Sends a `201 Created` JSON response.
pub fn sendCreated(response: *const Response, json_body: []const u8) !void {
    try writeResponse(response, 201, "Created", "application/json", json_body);
}

/// Sends a `202 Accepted` JSON response (for asynchronous operations).
pub fn sendAccepted(response: *const Response, json_body: []const u8) !void {
    try writeResponse(response, 202, "Accepted", "application/json", json_body);
}

/// Sends a `400 Bad Request` JSON error response.
pub fn sendBadRequest(response: *const Response, message: []const u8) !void {
    const body = try std.fmt.allocPrint(response.allocator, "{{\"error\":\"Bad Request\",\"message\":\"{s}\"}}", .{message});
    defer response.allocator.free(body);
    try writeResponse(response, 400, "Bad Request", "application/json", body);
}

/// Sends a `401 Unauthorized` JSON error response.
pub fn sendUnauthorized(response: *const Response, message: []const u8) !void {
    const body = try std.fmt.allocPrint(response.allocator, "{{\"error\":\"Unauthorized\",\"message\":\"{s}\"}}", .{message});
    defer response.allocator.free(body);
    try writeResponse(response, 401, "Unauthorized", "application/json", body);
}

/// Sends a `403 Forbidden` JSON error response.
pub fn sendForbidden(response: *const Response, message: []const u8) !void {
    const body = try std.fmt.allocPrint(response.allocator, "{{\"error\":\"Forbidden\",\"message\":\"{s}\"}}", .{message});
    defer response.allocator.free(body);
    try writeResponse(response, 403, "Forbidden", "application/json", body);
}

/// Sends a `404 Not Found` JSON error response.
pub fn sendNotFound(response: *const Response, message: []const u8) !void {
    const body = try std.fmt.allocPrint(response.allocator, "{{\"error\":\"Not Found\",\"message\":\"{s}\"}}", .{message});
    defer response.allocator.free(body);
    try writeResponse(response, 404, "Not Found", "application/json", body);
}

/// Sends a `500 Internal Server Error` JSON error response.
pub fn sendInternalError(response: *const Response, message: []const u8) !void {
    const body = try std.fmt.allocPrint(response.allocator, "{{\"error\":\"Internal Server Error\",\"message\":\"{s}\"}}", .{message});
    defer response.allocator.free(body);
    try writeResponse(response, 500, "Internal Server Error", "application/json", body);
}

/// Extracts a query parameter value by key from a URL string (e.g. "?status=working").
pub fn getQueryParam(url: []const u8, key: []const u8) ?[]const u8 {
    const qmark = std.mem.indexOf(u8, url, "?") orelse return null;
    const query = url[qmark + 1 ..];
    var it = std.mem.splitScalar(u8, query, '&');
    while (it.next()) |pair| {
        if (std.mem.indexOf(u8, pair, "=")) |eq| {
            const k = pair[0..eq];
            const v = pair[eq + 1 ..];
            if (std.mem.eql(u8, k, key)) {
                return v;
            }
        }
    }
    return null;
}
