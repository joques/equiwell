const std = @import("std");

/// Safe JSON parsing and formatting utilities.
pub const JsonUtil = struct {
    pub fn parse(comptime T: type, allocator: std.mem.Allocator, payload: []const u8) !std.json.Parsed(T) {
        return std.json.parseFromSlice(T, allocator, payload, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        });
    }
};
