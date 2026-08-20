const std = @import("std");
const DataStore = @import("../db/store.zig").DataStore;
const TelemetryRecord = @import("../models/telemetry.zig").TelemetryRecord;
const jwt = @import("../auth/jwt.zig");
const http_util = @import("../utils/http_util.zig");

/// Handles `POST /boreholes/{id}/telemetry` - Ingests real-time IoT sensor readings (drawdown, flow rate, solar battery).
pub fn handleIngestTelemetry(allocator: std.mem.Allocator, store: *DataStore, borehole_id: []const u8, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Only Maintenance Crew or Administrators can submit IoT sensor telemetry.");
    }

    const parsed = std.json.parseFromSlice(struct {
        drawdown_m: f64,
        recovery_time_mins: u32,
        solar_battery_level: u32,
        flow_rate_lpm: f64,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON telemetry payload");
    };
    defer parsed.deinit();

    const new_id = try std.fmt.allocPrint(store.allocator, "TEL-{0d:0>5}", .{store.telemetry.items.len + 1});

    const tel: TelemetryRecord = .{
        .id = new_id,
        .borehole_id = try store.allocator.dupe(u8, borehole_id),
        .timestamp = "2026-08-19T12:00:00Z",
        .drawdown_m = parsed.value.drawdown_m,
        .recovery_time_mins = parsed.value.recovery_time_mins,
        .solar_battery_level = parsed.value.solar_battery_level,
        .flow_rate_lpm = parsed.value.flow_rate_lpm,
    };

    store.mutex.lock();
    try store.telemetry.append(store.allocator, tel);
    store.mutex.unlock();

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"IoT sensor telemetry ingested successfully.\",\"telemetry_id\":\"{s}\",\"borehole_id\":\"{s}\"}}",
        .{ new_id, borehole_id }
    );
    defer allocator.free(res_json);

    try http_util.sendCreated(response, res_json);
}

/// Handles `GET /maintenance-alerts` - Retrieves emergency dispatch tickets for broken or malfunctioning assets.
pub fn handleGetMaintenanceAlerts(allocator: std.mem.Allocator, store: *DataStore, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Access to maintenance repair dispatch alerts is restricted.");
    }

    store.mutex.lock();
    defer store.mutex.unlock();

    var list = std.ArrayList(u8).empty;
    defer list.deinit(allocator);

    try list.appendSlice(allocator, "[");
    for (store.alerts.items, 0..) |a, i| {
        if (i > 0) try list.appendSlice(allocator, ",");
        const item_str = try std.fmt.allocPrint(allocator,
            "{{\"borehole_id\":\"{s}\",\"borehole_name\":\"{s}\",\"status\":\"{s}\",\"issue\":\"{s}\",\"reported_at\":\"{s}\",\"urgency\":\"{s}\"}}",
            .{ a.borehole_id, a.borehole_name, a.status, a.issue, a.reported_at, a.urgency }
        );
        defer allocator.free(item_str);
        try list.appendSlice(allocator, item_str);
    }
    try list.appendSlice(allocator, "]");

    try http_util.sendOk(response, list.items);
}

/// Handles `GET /boreholes/{id}/history` - Retrieves multi-year average yield performance history.
pub fn handleGetYieldHistory(allocator: std.mem.Allocator, borehole_id: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Access to engineering yield history is restricted.");
    }

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"borehole_id\":\"{s}\",\"yearly_average_yield\":[{{\"year\":2024,\"average_yield_lph\":1600}},{{\"year\":2025,\"average_yield_lph\":1550}},{{\"year\":2026,\"average_yield_lph\":1500}}]}}",
        .{borehole_id}
    );
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}
