const std = @import("std");

/// Cross-Origin Resource Sharing (CORS) header provider and pre-flight handling.
pub const Cors = struct {
    pub const headers =
        "Access-Control-Allow-Origin: *\r\n" ++
        "Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS\r\n" ++
        "Access-Control-Allow-Headers: Content-Type, Authorization\r\n";

    pub fn formatHeaders(allocator: std.mem.Allocator, allowed_origins: []const u8) ![]const u8 {
        return std.fmt.allocPrint(allocator, "Access-Control-Allow-Origin: {s}\r\nAccess-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, Authorization\r\n", .{allowed_origins});
    }
};
