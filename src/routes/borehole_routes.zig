const std = @import("std");
const BoreholeService = @import("../services/borehole_service.zig").BoreholeService;
const Request = @import("../server/request.zig").Request;
const Response = @import("../server/response.zig").Response;
const BoreholeStatus = @import("../models/borehole.zig").BoreholeStatus;
const PumpType = @import("../models/borehole.zig").PumpType;
const Middleware = @import("../server/middleware.zig").Middleware;
const Rbac = @import("../auth/rbac.zig").Rbac;

/// GET /boreholes
pub fn handleGetBoreholes(service: *const BoreholeService, req: *const Request, res: *const Response) !void {
    const status_str = req.getQueryParam("status");
    const pump_str = req.getQueryParam("pump_type");

    var status_filter: ?BoreholeStatus = null;
    if (status_str) |s| {
        status_filter = BoreholeStatus.fromString(s);
    }

    var pump_filter: ?PumpType = null;
    if (pump_str) |p| {
        pump_filter = PumpType.fromString(p);
    }

    const is_staff = if (req.user) |u| Rbac.isMaintenanceOrAdmin(u) else false;

    const boreholes = try service.getBoreholes(res.allocator, status_filter, pump_filter, is_staff);
    defer res.allocator.free(boreholes);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(res.allocator);
    try buf.appendSlice(res.allocator, "[");
    for (boreholes, 0..) |b, i| {
        if (i > 0) try buf.appendSlice(res.allocator, ",");
        const item = try std.fmt.allocPrint(res.allocator,
            "{{\"id\":\"{s}\",\"name\":\"{s}\",\"lat\":{d:.4},\"lng\":{d:.4},\"depth_m\":{d:.1},\"pump_type\":\"{s}\",\"yield_lph\":{d},\"status\":\"{s}\",\"water_quality\":\"{s}\",\"implemented_date\":\"{s}\",\"last_maintained\":\"{s}\",\"is_visible\":{s}}}",
            .{
                b.id,
                b.name,
                b.lat,
                b.lng,
                b.depth_m,
                b.pump_type.toString(),
                b.yield_lph,
                b.status.toString(),
                b.water_quality,
                b.implemented_date,
                b.last_maintained,
                if (b.is_visible) "true" else "false",
            }
        );
        defer res.allocator.free(item);
        try buf.appendSlice(res.allocator, item);
    }
    try buf.appendSlice(res.allocator, "]");

    try res.ok(buf.items);
}

/// GET /boreholes/{id}
pub fn handleGetBoreholeById(service: *const BoreholeService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    _ = req;
    const b = service.getBoreholeById(borehole_id) orelse return try res.notFound("Borehole not found.");

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"id\":\"{s}\",\"name\":\"{s}\",\"lat\":{d:.4},\"lng\":{d:.4},\"depth_m\":{d:.1},\"pump_type\":\"{s}\",\"yield_lph\":{d},\"status\":\"{s}\",\"water_quality\":\"{s}\",\"implemented_date\":\"{s}\",\"last_maintained\":\"{s}\",\"is_visible\":{s},\"installed_by\":\"EquiWell Field Team\"}}",
        .{
            b.id,
            b.name,
            b.lat,
            b.lng,
            b.depth_m,
            b.pump_type.toString(),
            b.yield_lph,
            b.status.toString(),
            b.water_quality,
            b.implemented_date,
            b.last_maintained,
            if (b.is_visible) "true" else "false",
        }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// POST /boreholes
pub fn handleCreateBorehole(service: *const BoreholeService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Admins or Maintenance Crew can create boreholes.");
    }

    const parsed = std.json.parseFromSlice(struct {
        name: []const u8,
        lat: f64,
        lng: f64,
        depth_m: f64,
        pump_type: []const u8,
        yield_lph: u32,
        implemented_date: ?[]const u8 = null,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid borehole creation JSON payload.");
    };
    defer parsed.deinit();

    const pump_type = PumpType.fromString(parsed.value.pump_type) orelse .solar;

    const result = try service.createBorehole(
        res.allocator,
        parsed.value.name,
        parsed.value.lat,
        parsed.value.lng,
        parsed.value.depth_m,
        pump_type,
        parsed.value.yield_lph,
        parsed.value.implemented_date,
    );

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"Borehole registered successfully.\",\"borehole_id\":\"{s}\",\"implemented_date\":\"{s}\"}}",
        .{ result.borehole_id, result.implemented_date }
    );
    defer res.allocator.free(json);

    try res.created(json);
}

/// PUT /boreholes/{id}
pub fn handleUpdateBorehole(service: *const BoreholeService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAdmin(req, res)) return;

    const parsed = std.json.parseFromSlice(struct {
        name: []const u8,
        depth_m: f64,
        pump_type: []const u8,
        yield_lph: u32,
        implemented_date: ?[]const u8 = null,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid update payload.");
    };
    defer parsed.deinit();

    const pump_type = PumpType.fromString(parsed.value.pump_type) orelse .solar;

    if (!service.updateBorehole(borehole_id, parsed.value.name, parsed.value.depth_m, pump_type, parsed.value.yield_lph, parsed.value.implemented_date)) {
        return try res.notFound("Borehole not found.");
    }

    const imp_date = parsed.value.implemented_date orelse "2024-03-15";
    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"Borehole {s} updated successfully.\",\"implemented_date\":\"{s}\"}}",
        .{ borehole_id, imp_date }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// PATCH /boreholes/{id}
pub fn handlePatchBorehole(service: *const BoreholeService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Admins or Maintenance Crew can patch boreholes.");
    }

    const parsed = std.json.parseFromSlice(struct {
        status: ?[]const u8 = null,
        is_visible: ?bool = null,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid patch payload.");
    };
    defer parsed.deinit();

    var new_status: ?BoreholeStatus = null;
    if (parsed.value.status) |st| {
        new_status = BoreholeStatus.fromString(st);
    }

    if (!service.patchBorehole(borehole_id, new_status, parsed.value.is_visible)) {
        return try res.notFound("Borehole not found.");
    }

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"Borehole {s} operational status patched.\"}}",
        .{borehole_id}
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// DELETE /boreholes/{id}
pub fn handleDeleteBorehole(service: *const BoreholeService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAdmin(req, res)) return;

    if (!service.deleteBorehole(borehole_id)) {
        return try res.notFound("Borehole not found.");
    }

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"Borehole {s} successfully removed from the system.\"}}",
        .{borehole_id}
    );
    defer res.allocator.free(json);

    try res.ok(json);
}
