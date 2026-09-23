const std = @import("std");

/// IoT sensor measurements ingested from smart water meters and solar controllers.
pub const TelemetryRecord = struct {
    id: []const u8,
    borehole_id: []const u8,
    drawdown_m: f64,
    recovery_time_mins: u32,
    solar_battery_level: u8,
    flow_rate_lpm: f64,
    timestamp: []const u8,
};

/// High-priority maintenance alert requiring field technician dispatch.
pub const MaintenanceAlert = struct {
    borehole_id: []const u8,
    borehole_name: []const u8,
    status: []const u8,
    issue: []const u8,
    reported_at: []const u8,
    urgency: []const u8,
};

/// Historical annual yield delivery entry for a borehole asset.
pub const YieldHistoryEntry = struct {
    year: u16,
    average_yield_lph: u32,
};
