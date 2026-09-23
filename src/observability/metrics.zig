const std = @import("std");

/// In-memory server performance metrics and request counters.
pub const Metrics = struct {
    total_requests: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_2xx: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_4xx: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_5xx: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    pub fn recordRequest(self: *Metrics, status_code: u16) void {
        _ = self.total_requests.fetchAdd(1, .monotonic);
        if (status_code >= 200 and status_code < 300) {
            _ = self.total_2xx.fetchAdd(1, .monotonic);
        } else if (status_code >= 400 and status_code < 500) {
            _ = self.total_4xx.fetchAdd(1, .monotonic);
        } else if (status_code >= 500) {
            _ = self.total_5xx.fetchAdd(1, .monotonic);
        }
    }
};

pub const default_metrics: Metrics = .{};
