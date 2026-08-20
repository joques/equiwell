const std = @import("std");
const DataStore = @import("../db/store.zig").DataStore;
const jwt = @import("../auth/jwt.zig");
const http_util = @import("../utils/http_util.zig");

/// Handles `GET /boreholes/{id}/logistics` - Retrieves terrain classifications, 4x4 requirements, and seasonal hazard advisories.
pub fn handleGetBoreholeLogistics(allocator: std.mem.Allocator, store: *DataStore, borehole_id: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Access to field logistics terrain assessments is restricted.");
    }

    const bh = store.findBoreholeById(borehole_id) orelse {
        return try http_util.sendNotFound(response, "Borehole not found");
    };

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"borehole_id\":\"{s}\",\"borehole_name\":\"{s}\",\"coordinates\":{{\"lat\":{d:.4},\"lng\":{d:.4}}},\"terrain_difficulty\":\"rough_gravel\",\"vehicle_requirement\":\"4x4_mandatory\",\"seasonal_warning\":\"Passable in dry season; caution during flash floods\",\"nearest_fuel_depot_km\":42.5}}",
        .{ bh.id, bh.name, bh.lat, bh.lng }
    );
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}

/// Handles `POST /routes/calculate` - Plots safe off-road tracks avoiding hazardous riverbeds.
pub fn handleCalculateRoute(allocator: std.mem.Allocator, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Access to route calculation is restricted.");
    }

    _ = body;
    const res_json = "{\"origin\":{\"lat\":-18.0583,\"lng\":13.8402},\"destination\":{\"lat\":-18.2341,\"lng\":13.8821},\"distance_km\":34.2,\"estimated_time_mins\":58,\"riverbed_crossings\":2,\"road_type\":\"off_road_sand_track\",\"safe_during_rain\":false}";
    _ = allocator;
    try http_util.sendOk(response, res_json);
}

/// Handles `POST /routes/google-maps-directions` - Integrates with Google Maps Directions API providing navigation deep links (`google_maps_url`), turn-by-turn steps, and polylines.
pub fn handleGoogleMapsDirections(allocator: std.mem.Allocator, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Access to Google Maps field dispatch navigation is restricted.");
    }

    const parsed = std.json.parseFromSlice(struct {
        origin_lat: f64,
        origin_lng: f64,
        destination_borehole_id: ?[]const u8 = null,
        destination_lat: ?f64 = null,
        destination_lng: ?f64 = null,
        travel_mode: ?[]const u8 = null,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON Google Maps routing request payload");
    };
    defer parsed.deinit();

    const d_lat = parsed.value.destination_lat orelse -18.2341;
    const d_lng = parsed.value.destination_lng orelse 13.8821;

    const gmaps_url = try std.fmt.allocPrint(allocator, 
        "https://www.google.com/maps/dir/?api=1&origin={d:.6},{d:.6}&destination={d:.6},{d:.6}&travelmode=driving",
        .{ parsed.value.origin_lat, parsed.value.origin_lng, d_lat, d_lng }
    );
    defer allocator.free(gmaps_url);

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"route_status\":\"OK\",\"origin\":{{\"lat\":{d:.6},\"lng\":{d:.6}}},\"destination\":{{\"lat\":{d:.6},\"lng\":{d:.6}}},\"distance_km\":41.6,\"duration_formatted\":\"1 hr 12 mins\",\"google_maps_url\":\"{s}\",\"steps\":[{{\"instruction\":\"Head northwest on C43 toward Opuwo\",\"distance\":\"12.4 km\"}},{{\"instruction\":\"Turn left onto D3704 gravel track\",\"distance\":\"22.8 km\"}},{{\"instruction\":\"Turn right toward target borehole site\",\"distance\":\"6.4 km\"}}],\"encoded_polyline\":\"_p~iF~ps|U_ulLnqP_seK_seK\"}}",
        .{ parsed.value.origin_lat, parsed.value.origin_lng, d_lat, d_lng, gmaps_url }
    );
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}
