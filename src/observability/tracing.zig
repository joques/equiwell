const std = @import("std");

/// Request tracing identifier generator and context holder.
pub const Tracing = struct {
    pub fn generateRequestId(allocator: std.mem.Allocator, counter: u64) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "req-{d}", .{counter});
    }
};
