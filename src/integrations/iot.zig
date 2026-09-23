const std = @import("std");
const TelemetryRecord = @import("../models/telemetry.zig").TelemetryRecord;

/// IoT sensor payload parser and validation adapter.
pub const IotAdapter = struct {
    pub fn parsePayload(allocator: std.mem.Allocator, borehole_id: []const u8, drawdown_m: f64, recovery_mins: u32, battery_pct: u8, flow_lpm: f64) !TelemetryRecord {
        _ = allocator;
        return .{
            .id = "TEL-00001",
            .borehole_id = borehole_id,
            .drawdown_m = drawdown_m,
            .recovery_time_mins = recovery_mins,
            .solar_battery_level = battery_pct,
            .flow_rate_lpm = flow_lpm,
            .timestamp = "2026-09-23T12:00:00Z",
        };
    }
};
