const std = @import("std");

/// Terrain difficulty and accessibility profile for navigating to a borehole asset.
pub const LogisticsAccessibility = struct {
    borehole_id: []const u8,
    borehole_name: []const u8,
    lat: f64,
    lng: f64,
    terrain_difficulty: []const u8,
    vehicle_requirement: []const u8,
    seasonal_warning: []const u8,
    nearest_fuel_depot_km: f64,
};

/// Navigation turn-by-turn step.
pub const RouteStep = struct {
    instruction: []const u8,
    distance: []const u8,
};

/// Google Maps Directions API response payload structure.
pub const GoogleMapsRouteResponse = struct {
    route_status: []const u8,
    origin_lat: f64,
    origin_lng: f64,
    destination_lat: f64,
    destination_lng: f64,
    distance_km: f64,
    duration_formatted: []const u8,
    google_maps_url: []const u8,
    encoded_polyline: []const u8,
};
