const std = @import("std");
const TokenPayload = @import("../auth/jwt.zig").TokenPayload;

/// Parsed HTTP Request encapsulation.
pub const Request = struct {
    method: []const u8,
    path: []const u8,
    raw_path: []const u8,
    full_url: []const u8,
    headers: []const u8,
    body: []const u8,
    user: ?TokenPayload = null,
    request_id: []const u8 = "req-0001",
    allocator: std.mem.Allocator,

    pub fn getQueryParam(self: Request, key: []const u8) ?[]const u8 {
        const qmark = std.mem.indexOf(u8, self.full_url, "?") orelse return null;
        const query = self.full_url[qmark + 1 ..];
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
};
