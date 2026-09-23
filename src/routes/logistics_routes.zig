const std = @import("std");
const LogisticsService = @import("../services/logistics_service.zig").LogisticsService;
const Request = @import("../server/request.zig").Request;
const Response = @import("../server/response.zig").Response;
const Middleware = @import("../server/middleware.zig").Middleware;
const Rbac = @import("../auth/rbac.zig").Rbac;

/// GET /boreholes/{id}/logistics
pub fn handleGetBoreholeLogistics(service: *const LogisticsService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Maintenance Crew or Admins can access logistics profiles.");
    }

    const log = service.getBoreholeLogistics(borehole_id) catch |err| {
        if (err == error.NotFound) return try res.notFound("Borehole not found.");
        return try res.internalError("Failed to retrieve logistics profile.");
    };

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"borehole_id\":\"{s}\",\"borehole_name\":\"{s}\",\"coordinates\":{{\"lat\":{d:.4},\"lng\":{d:.4}}},\"terrain_difficulty\":\"{s}\",\"vehicle_requirement\":\"{s}\",\"seasonal_warning\":\"{s}\",\"nearest_fuel_depot_km\":{d:.1}}}",
        .{ log.borehole_id, log.borehole_name, log.lat, log.lng, log.terrain_difficulty, log.vehicle_requirement, log.seasonal_warning, log.nearest_fuel_depot_km }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// POST /routes/calculate
pub fn handleCalculateRoute(service: *const LogisticsService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Maintenance Crew or Admins can calculate transit routes.");
    }

    const parsed = std.json.parseFromSlice(struct {
        start_coordinates: []const u8,
        destination_borehole_id: []const u8,
        vehicle_type: []const u8,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid route calculation JSON payload.");
    };
    defer parsed.deinit();

    const r = service.calculateRoute(res.allocator, parsed.value.destination_borehole_id) catch |err| {
        if (err == error.NotFound) return try res.notFound("Destination borehole not found.");
        return try res.internalError("Failed to calculate route.");
    };

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"origin\":{{\"lat\":{d:.4},\"lng\":{d:.4}}},\"destination\":{{\"lat\":{d:.4},\"lng\":{d:.4}}},\"distance_km\":{d:.1},\"estimated_time_mins\":{d},\"riverbed_crossings\":{d},\"road_type\":\"{s}\",\"safe_during_rain\":{s}}}",
        .{ r.origin_lat, r.origin_lng, r.dest_lat, r.dest_lng, r.distance_km, r.estimated_time_mins, r.riverbed_crossings, r.road_type, if (r.safe_during_rain) "true" else "false" }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// POST /routes/google-maps-directions
pub fn handleGoogleMapsDirections(service: *const LogisticsService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Maintenance Crew or Admins can request Google Maps directions.");
    }

    const parsed = std.json.parseFromSlice(struct {
        origin_lat: f64,
        origin_lng: f64,
        destination_lat: f64,
        destination_lng: f64,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid coordinate payload.");
    };
    defer parsed.deinit();

    const dir = try service.getDirections(res.allocator, parsed.value.origin_lat, parsed.value.origin_lng, parsed.value.destination_lat, parsed.value.destination_lng);

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"route_status\":\"{s}\",\"origin\":{{\"lat\":{d:.4},\"lng\":{d:.4}}},\"destination\":{{\"lat\":{d:.4},\"lng\":{d:.4}}},\"distance_km\":{d:.1},\"duration_formatted\":\"{s}\",\"google_maps_url\":\"{s}\",\"steps\":[{{\"instruction\":\"Head northwest on C43 toward Opuwo\",\"distance\":\"12.4 km\"}},{{\"instruction\":\"Turn left onto D3704 gravel track\",\"distance\":\"22.8 km\"}},{{\"instruction\":\"Turn right toward target borehole site\",\"distance\":\"6.4 km\"}}],\"encoded_polyline\":\"{s}\"}}",
        .{ dir.route_status, dir.origin_lat, dir.origin_lng, dir.destination_lat, dir.destination_lng, dir.distance_km, dir.duration_formatted, dir.google_maps_url, dir.encoded_polyline }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}
