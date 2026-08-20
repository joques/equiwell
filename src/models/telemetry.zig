const std = @import("std");

/// Real-time IoT sensor telemetry reading transmitted from automated borehole sensors.
pub const TelemetryRecord = struct {
    /// Unique telemetry ingest ID (e.g. "TEL-00001").
    id: []const u8,
    /// Target borehole ID.
    borehole_id: []const u8,
    /// UTC timestamp of the measurement.
    timestamp: []const u8,
    /// Dynamic water level drawdown below static level in meters.
    drawdown_m: f64,
    /// Duration required for water table to recover back to static level in minutes.
    recovery_time_mins: u32,
    /// Solar battery energy storage charge percentage (0-100%).
    solar_battery_level: u32,
    /// Instantaneous water discharge flow rate in Liters per Minute (L/min).
    flow_rate_lpm: f64,
};

/// High-priority maintenance repair ticket for broken or underperforming assets.
pub const MaintenanceAlert = struct {
    /// Target borehole code.
    borehole_id: []const u8,
    /// Target borehole display name.
    borehole_name: []const u8,
    /// Current asset status.
    status: []const u8,
    /// Diagnosed mechanical or electrical fault description.
    issue: []const u8,
    /// Timestamp when failure was reported or automatically triggered.
    reported_at: []const u8,
    /// Priority level ("critical", "high", "medium", "low").
    urgency: []const u8,
};

/// Annual average yield delivery metrics for historical aquifer analysis.
pub const YieldHistoryEntry = struct {
    /// Calendar year (e.g. 2024, 2025, 2026).
    year: u32,
    /// Mean measured discharge yield in Liters per Hour (L/h).
    average_yield_lph: u32,
};
