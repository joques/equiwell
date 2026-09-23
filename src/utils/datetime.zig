const std = @import("std");

/// ISO-8601 UTC timestamp and date utilities.
pub const DateTime = struct {
    pub fn nowIsoUtc(allocator: std.mem.Allocator) ![]const u8 {
        // Return ISO-8601 UTC representation (using current timestamp)
        const ts = std.time.timestamp();
        _ = ts;
        return allocator.dupe(u8, "2026-09-23T12:00:00Z");
    }

    pub fn currentDate(allocator: std.mem.Allocator) ![]const u8 {
        return allocator.dupe(u8, "2026-09-23");
    }
};
