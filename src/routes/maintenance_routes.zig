const std = @import("std");
const TelemetryService = @import("../services/telemetry_service.zig").TelemetryService;
const MaintenanceService = @import("../services/maintenance_service.zig").MaintenanceService;
const Request = @import("../server/request.zig").Request;
const Response = @import("../server/response.zig").Response;
const Middleware = @import("../server/middleware.zig").Middleware;
const Rbac = @import("../auth/rbac.zig").Rbac;
const Validation = @import("../utils/validation.zig").Validation;

/// POST /boreholes/{id}/telemetry
pub fn handleIngestTelemetry(service: *const TelemetryService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Maintenance Crew or Admins can submit telemetry records.");
    }
    if (!Validation.isValidString(borehole_id, 1, 50)) {
        return try res.badRequest("Invalid borehole ID parameter.");
    }

    const parsed = std.json.parseFromSlice(struct {
        drawdown_m: f64,
        recovery_time_mins: u32,
        solar_battery_level: u8,
        flow_rate_lpm: f64,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid telemetry JSON payload.");
    };
    defer parsed.deinit();

    if (!Validation.isValidPositiveFloat(parsed.value.drawdown_m, 1000.0)) {
        return try res.badRequest("Invalid drawdown measurement. Must be a finite non-negative number <= 1000m.");
    }
    if (parsed.value.recovery_time_mins > 100000) {
        return try res.badRequest("Invalid recovery time. Must be <= 100,000 minutes.");
    }
    if (!Validation.isValidPercentage(parsed.value.solar_battery_level)) {
        return try res.badRequest("Invalid solar battery level. Must be between 0 and 100 percent.");
    }
    if (!Validation.isValidPositiveFloat(parsed.value.flow_rate_lpm, 50000.0)) {
        return try res.badRequest("Invalid flow rate. Must be a finite non-negative number <= 50,000 L/min.");
    }

    const result = service.ingestTelemetry(
        res.allocator,
        borehole_id,
        parsed.value.drawdown_m,
        parsed.value.recovery_time_mins,
        parsed.value.solar_battery_level,
        parsed.value.flow_rate_lpm,
    ) catch |err| {
        if (err == error.NotFound) return try res.notFound("Borehole not found.");
        return try res.internalError("Failed to ingest telemetry.");
    };

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"IoT sensor telemetry ingested successfully.\",\"telemetry_id\":\"{s}\",\"borehole_id\":\"{s}\"}}",
        .{ result.telemetry_id, result.borehole_id }
    );
    defer res.allocator.free(json);

    try res.created(json);
}

/// GET /maintenance-alerts
pub fn handleGetMaintenanceAlerts(service: *const MaintenanceService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Maintenance Crew or Admins can view maintenance alerts.");
    }

    const alerts = try service.listAlerts(res.allocator);
    defer res.allocator.free(alerts);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(res.allocator);
    try buf.appendSlice(res.allocator, "[");
    for (alerts, 0..) |a, i| {
        if (i > 0) try buf.appendSlice(res.allocator, ",");
        const item = try std.fmt.allocPrint(res.allocator,
            "{{\"borehole_id\":\"{s}\",\"borehole_name\":\"{s}\",\"status\":\"{s}\",\"issue\":\"{s}\",\"reported_at\":\"{s}\",\"urgency\":\"{s}\"}}",
            .{ a.borehole_id, a.borehole_name, a.status, a.issue, a.reported_at, a.urgency }
        );
        defer res.allocator.free(item);
        try buf.appendSlice(res.allocator, item);
    }
    try buf.appendSlice(res.allocator, "]");

    try res.ok(buf.items);
}

/// GET /boreholes/{id}/history
pub fn handleGetYieldHistory(service: *const MaintenanceService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Maintenance Crew or Admins can view yield histories.");
    }
    if (!Validation.isValidString(borehole_id, 1, 50)) {
        return try res.badRequest("Invalid borehole ID parameter.");
    }

    const history = service.getYieldHistory(res.allocator, borehole_id) catch |err| {
        if (err == error.NotFound) return try res.notFound("Borehole not found.");
        return try res.internalError("Failed to retrieve yield history.");
    };
    defer res.allocator.free(history);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(res.allocator);

    const prefix = try std.fmt.allocPrint(res.allocator, "{{\"borehole_id\":\"{s}\",\"yearly_average_yield\":[", .{borehole_id});
    defer res.allocator.free(prefix);
    try buf.appendSlice(res.allocator, prefix);

    for (history, 0..) |h, i| {
        if (i > 0) try buf.appendSlice(res.allocator, ",");
        const item = try std.fmt.allocPrint(res.allocator, "{{\"year\":{d},\"average_yield_lph\":{d}}}", .{ h.year, h.average_yield_lph });
        defer res.allocator.free(item);
        try buf.appendSlice(res.allocator, item);
    }
    try buf.appendSlice(res.allocator, "]}");

    try res.ok(buf.items);
}
