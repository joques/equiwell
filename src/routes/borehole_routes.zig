const std = @import("std");
const DataStore = @import("../db/store.zig").DataStore;
const Borehole = @import("../models/borehole.zig").Borehole;
const PumpType = @import("../models/borehole.zig").PumpType;
const BoreholeStatus = @import("../models/borehole.zig").BoreholeStatus;
const jwt = @import("../auth/jwt.zig");
const http_util = @import("../utils/http_util.zig");

/// Handles `GET /boreholes` - Lists all boreholes with status, pump type, and visibility filters.
pub fn handleGetBoreholes(allocator: std.mem.Allocator, store: *DataStore, url: []const u8, current_user: ?jwt.TokenPayload, response: *const http_util.Response) !void {
    store.mutex.lock();
    defer store.mutex.unlock();

    const status_filter = http_util.getQueryParam(url, "status");
    const pump_filter = http_util.getQueryParam(url, "pump_type");
    const is_viewer = if (current_user) |u| (u.role == .viewer) else true;

    var list = std.ArrayList(u8).empty;
    defer list.deinit(allocator);

    try list.appendSlice(allocator, "[");
    var count: usize = 0;

    for (store.boreholes.items) |bh| {
        // Viewers can only see visible boreholes
        if (is_viewer and !bh.is_visible) continue;

        // Status query filter
        if (status_filter) |sf| {
            if (!std.mem.eql(u8, bh.status.toString(), sf)) continue;
        }

        // Pump type query filter
        if (pump_filter) |pf| {
            if (!std.mem.eql(u8, bh.pump_type.toString(), pf)) continue;
        }

        if (count > 0) try list.appendSlice(allocator, ",");
        count += 1;

        const item_str = try std.fmt.allocPrint(allocator,
            "{{\"id\":\"{s}\",\"name\":\"{s}\",\"lat\":{d:.4},\"lng\":{d:.4},\"depth_m\":{d:.1},\"pump_type\":\"{s}\",\"yield_lph\":{d},\"status\":\"{s}\",\"water_quality\":\"{s}\",\"implemented_date\":\"{s}\",\"last_maintained\":\"{s}\",\"is_visible\":{}}}",
            .{
                bh.id,
                bh.name,
                bh.lat,
                bh.lng,
                bh.depth_m,
                bh.pump_type.toString(),
                bh.yield_lph,
                bh.status.toString(),
                bh.water_quality,
                bh.implemented_date,
                bh.last_maintained,
                bh.is_visible,
            }
        );
        defer allocator.free(item_str);
        try list.appendSlice(allocator, item_str);
    }
    try list.appendSlice(allocator, "]");

    try http_util.sendOk(response, list.items);
}

/// Handles `POST /boreholes` - Registers a new borehole with historical commissioning date (`implemented_date`).
pub fn handleCreateBorehole(allocator: std.mem.Allocator, store: *DataStore, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Only Administrators or Maintenance Leads can register new boreholes.");
    }

    const parsed = std.json.parseFromSlice(struct {
        name: []const u8,
        lat: f64,
        lng: f64,
        depth_m: f64,
        pump_type: []const u8,
        yield_lph: u32,
        implemented_date: ?[]const u8 = null,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON borehole registration payload");
    };
    defer parsed.deinit();

    const p_type = PumpType.fromString(parsed.value.pump_type) orelse .solar;
    const new_id = try std.fmt.allocPrint(store.allocator, "BH-{0d:0>4}", .{1000 + store.boreholes.items.len + 1});
    const impl_date = parsed.value.implemented_date orelse "2026-08-19";

    const bh: Borehole = .{
        .id = new_id,
        .name = try store.allocator.dupe(u8, parsed.value.name),
        .lat = parsed.value.lat,
        .lng = parsed.value.lng,
        .depth_m = parsed.value.depth_m,
        .pump_type = p_type,
        .yield_lph = parsed.value.yield_lph,
        .status = .working,
        .water_quality = "potable",
        .implemented_date = try store.allocator.dupe(u8, impl_date),
        .last_maintained = "2026-08-19",
        .is_visible = true,
        .installed_by = try store.allocator.dupe(u8, current_user.name),
    };

    try store.addBorehole(bh);

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"Borehole registered successfully.\",\"borehole_id\":\"{s}\",\"implemented_date\":\"{s}\"}}",
        .{ new_id, impl_date }
    );
    defer allocator.free(res_json);

    try http_util.sendCreated(response, res_json);
}

/// Handles `GET /boreholes/{id}` - Retrieves complete engineering and operational details of a specific borehole.
pub fn handleGetBoreholeById(allocator: std.mem.Allocator, store: *DataStore, id: []const u8, response: *const http_util.Response) !void {
    const bh = store.findBoreholeById(id) orelse {
        return try http_util.sendNotFound(response, "Borehole not found");
    };

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"id\":\"{s}\",\"name\":\"{s}\",\"lat\":{d:.4},\"lng\":{d:.4},\"depth_m\":{d:.1},\"pump_type\":\"{s}\",\"yield_lph\":{d},\"status\":\"{s}\",\"water_quality\":\"{s}\",\"implemented_date\":\"{s}\",\"last_maintained\":\"{s}\",\"is_visible\":{},\"installed_by\":\"{s}\"}}",
        .{
            bh.id,
            bh.name,
            bh.lat,
            bh.lng,
            bh.depth_m,
            bh.pump_type.toString(),
            bh.yield_lph,
            bh.status.toString(),
            bh.water_quality,
            bh.implemented_date,
            bh.last_maintained,
            bh.is_visible,
            bh.installed_by,
        }
    );
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}

/// Handles `PUT /boreholes/{id}` - Updates all core borehole infrastructure parameters (Restricted to `admin`).
pub fn handleUpdateBorehole(allocator: std.mem.Allocator, store: *DataStore, id: []const u8, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin) {
        return try http_util.sendForbidden(response, "Only Administrators can alter core borehole infrastructure data.");
    }

    const parsed = std.json.parseFromSlice(struct {
        name: []const u8,
        depth_m: f64,
        pump_type: []const u8,
        yield_lph: u32,
        implemented_date: []const u8,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON borehole update payload");
    };
    defer parsed.deinit();

    const p_type = PumpType.fromString(parsed.value.pump_type) orelse .solar;
    const updated = try store.updateBoreholeFull(id, parsed.value.name, parsed.value.depth_m, p_type, parsed.value.yield_lph, parsed.value.implemented_date);

    if (!updated) {
        return try http_util.sendNotFound(response, "Borehole not found");
    }

    const res_json = try std.fmt.allocPrint(allocator, "{{\"message\":\"Borehole {s} updated successfully.\",\"implemented_date\":\"{s}\"}}", .{ id, parsed.value.implemented_date });
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}

/// Handles `PATCH /boreholes/{id}` - Partially updates operational status or map visibility.
pub fn handlePatchBorehole(allocator: std.mem.Allocator, store: *DataStore, id: []const u8, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Only Administrators or Maintenance Crews can modify borehole status.");
    }

    const parsed = std.json.parseFromSlice(struct {
        status: ?[]const u8 = null,
        is_visible: ?bool = null,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON patch payload");
    };
    defer parsed.deinit();

    var b_status: ?BoreholeStatus = null;
    if (parsed.value.status) |s| {
        b_status = BoreholeStatus.fromString(s);
    }

    const updated = store.patchBorehole(id, b_status, parsed.value.is_visible);
    if (!updated) {
        return try http_util.sendNotFound(response, "Borehole not found");
    }

    const res_json = try std.fmt.allocPrint(allocator, "{{\"message\":\"Borehole {s} operational status patched.\"}}", .{id});
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}

/// Handles `DELETE /boreholes/{id}` - Permanently removes a borehole asset (Restricted to `admin`).
pub fn handleDeleteBorehole(allocator: std.mem.Allocator, store: *DataStore, id: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin) {
        return try http_util.sendForbidden(response, "Only Administrators are authorized to permanently delete borehole records.");
    }

    const deleted = store.deleteBorehole(id);
    if (!deleted) {
        return try http_util.sendNotFound(response, "Borehole not found");
    }

    const res_json = try std.fmt.allocPrint(allocator, "{{\"message\":\"Borehole {s} successfully removed from the system.\"}}", .{id});
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}
