const std = @import("std");

/// Terrain difficulty and vehicular accessibility assessment for field dispatch.
pub const LogisticsAccessibility = struct {
    /// Target borehole code.
    borehole_id: []const u8,
    /// Target borehole name.
    borehole_name: []const u8,
    /// GPS latitude coordinate.
    lat: f64,
    /// GPS longitude coordinate.
    lng: f64,
    /// Terrain classification ("smooth_gravel", "rough_gravel", "deep_sand", "rocky_mountain").
    terrain_difficulty: []const u8,
    /// Mandatory vehicle specification ("standard_2wd", "4x4_recommended", "4x4_mandatory", "heavy_drilling_rig").
    vehicle_requirement: []const u8,
    /// Seasonal hazard warnings (flash floods, riverbed washouts).
    seasonal_warning: []const u8,
    /// Distance to nearest diesel fuel depot in kilometers.
    nearest_fuel_depot_km: f64,
};

/// Navigation route calculation including Google Maps Directions integration.
pub const GoogleMapsRouteResponse = struct {
    /// Overall route calculation status ("OK", "ROUTE_NOT_FOUND").
    route_status: []const u8,
    /// Total travel distance in kilometers.
    distance_km: f64,
    /// Formatted estimated travel time (e.g. "1 hr 12 mins").
    duration_formatted: []const u8,
    /// Direct Google Maps deep link for driver mobile navigation.
    google_maps_url: []const u8,
    /// Encoded route polyline string for map rendering.
    encoded_polyline: []const u8,
};
