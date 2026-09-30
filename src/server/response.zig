const std = @import("std");
const Cors = @import("cors.zig").Cors;

pub const SOCKET = usize;
pub const SOCKET_ERROR: i32 = -1;

extern "ws2_32" fn send(s: SOCKET, buf: [*]const u8, len: i32, flags: i32) callconv(std.builtin.CallingConvention.winapi) i32;

/// HTTP Response writer with socket transport, standardized formatting, and metrics tracking hooks.
pub const Response = struct {
    socket: SOCKET,
    allocator: std.mem.Allocator,
    status_code_ptr: ?*u16 = null,
    bytes_sent_ptr: ?*usize = null,

    pub fn writeAll(self: Response, data: []const u8) !void {
        var total_sent: usize = 0;
        while (total_sent < data.len) {
            const chunk = data[total_sent..];
            const sent = send(self.socket, chunk.ptr, @intCast(chunk.len), 0);
            if (sent == SOCKET_ERROR) {
                return error.SocketSendFailed;
            }
            total_sent += @intCast(sent);
        }
        if (self.bytes_sent_ptr) |ptr| {
            ptr.* += total_sent;
        }
    }

    pub fn sendRaw(self: Response, status_code: u16, status_text: []const u8, content_type: []const u8, body: []const u8) !void {
        if (self.status_code_ptr) |ptr| {
            ptr.* = status_code;
        }
        const header = try std.fmt.allocPrint(self.allocator, "HTTP/1.1 {d} {s}\r\nContent-Type: {s}\r\nContent-Length: {d}\r\n{s}Connection: close\r\n\r\n", .{ status_code, status_text, content_type, body.len, Cors.headers });
        defer self.allocator.free(header);

        try self.writeAll(header);
        if (body.len > 0) {
            try self.writeAll(body);
        }
    }

    pub fn ok(self: Response, json_body: []const u8) !void {
        try self.sendRaw(200, "OK", "application/json", json_body);
    }

    pub fn created(self: Response, json_body: []const u8) !void {
        try self.sendRaw(201, "Created", "application/json", json_body);
    }

    pub fn accepted(self: Response, json_body: []const u8) !void {
        try self.sendRaw(202, "Accepted", "application/json", json_body);
    }

    pub fn noContent(self: Response) !void {
        try self.sendRaw(204, "No Content", "text/plain", "");
    }

    pub fn badRequest(self: Response, message: []const u8) !void {
        const body = try std.fmt.allocPrint(self.allocator, "{{\"error\":\"Bad Request\",\"message\":\"{s}\"}}", .{message});
        defer self.allocator.free(body);
        try self.sendRaw(400, "Bad Request", "application/json", body);
    }

    pub fn unauthorized(self: Response, message: []const u8) !void {
        const body = try std.fmt.allocPrint(self.allocator, "{{\"error\":\"Unauthorized\",\"message\":\"{s}\"}}", .{message});
        defer self.allocator.free(body);
        try self.sendRaw(401, "Unauthorized", "application/json", body);
    }

    pub fn forbidden(self: Response, message: []const u8) !void {
        const body = try std.fmt.allocPrint(self.allocator, "{{\"error\":\"Forbidden\",\"message\":\"{s}\"}}", .{message});
        defer self.allocator.free(body);
        try self.sendRaw(403, "Forbidden", "application/json", body);
    }

    pub fn notFound(self: Response, message: []const u8) !void {
        const body = try std.fmt.allocPrint(self.allocator, "{{\"error\":\"Not Found\",\"message\":\"{s}\"}}", .{message});
        defer self.allocator.free(body);
        try self.sendRaw(404, "Not Found", "application/json", body);
    }

    pub fn payloadTooLarge(self: Response, message: []const u8) !void {
        const body = try std.fmt.allocPrint(self.allocator, "{{\"error\":\"Payload Too Large\",\"message\":\"{s}\"}}", .{message});
        defer self.allocator.free(body);
        try self.sendRaw(413, "Payload Too Large", "application/json", body);
    }

    pub fn requestHeaderFieldsTooLarge(self: Response, message: []const u8) !void {
        const body = try std.fmt.allocPrint(self.allocator, "{{\"error\":\"Request Header Fields Too Large\",\"message\":\"{s}\"}}", .{message});
        defer self.allocator.free(body);
        try self.sendRaw(431, "Request Header Fields Too Large", "application/json", body);
    }

    pub fn internalError(self: Response, message: []const u8) !void {
        const body = try std.fmt.allocPrint(self.allocator, "{{\"error\":\"Internal Server Error\",\"message\":\"{s}\"}}", .{message});
        defer self.allocator.free(body);
        try self.sendRaw(500, "Internal Server Error", "application/json", body);
    }

    pub fn serviceUnavailable(self: Response, message: []const u8) !void {
        const body = try std.fmt.allocPrint(self.allocator, "{{\"error\":\"Service Unavailable\",\"message\":\"{s}\"}}", .{message});
        defer self.allocator.free(body);
        try self.sendRaw(503, "Service Unavailable", "application/json", body);
    }
};
