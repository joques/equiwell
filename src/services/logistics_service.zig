const std = @import("std");
const BoreholeRepository = @import("../repositories/borehole_repository.zig").BoreholeRepository;
const GoogleMapsAdapter = @import("../integrations/google_maps.zig").GoogleMapsAdapter;
const LogisticsAccessibility = @import("../models/logistics.zig").LogisticsAccessibility;
const GoogleMapsRouteResponse = @import("../models/logistics.zig").GoogleMapsRouteResponse;

pub const LogisticsService = struct {
    borehole_repo: BoreholeRepository,
    gmaps_adapter: GoogleMapsAdapter,

    pub fn init(borehole_repo: BoreholeRepository, gmaps_adapter: GoogleMapsAdapter) LogisticsService {
        return .{
            .borehole_repo = borehole_repo,
            .gmaps_adapter = gmaps_adapter,
        };
    }

    pub fn getBoreholeLogistics(self: LogisticsService, borehole_id: []const u8) !LogisticsAccessibility {
        const bh = self.borehole_repo.findById(borehole_id) orelse return error.NotFound;

        return .{
            .borehole_id = bh.id,
            .borehole_name = bh.name,
            .lat = bh.lat,
            .lng = bh.lng,
            .terrain_difficulty = "rough_gravel",
            .vehicle_requirement = "4x4_mandatory",
            .seasonal_warning = "Passable in dry season; caution during flash floods",
            .nearest_fuel_depot_km = 42.5,
        };
    }

    pub fn calculateRoute(
        self: LogisticsService,
        allocator: std.mem.Allocator,
        destination_borehole_id: []const u8,
    ) !struct {
        origin_lat: f64,
        origin_lng: f64,
        dest_lat: f64,
        dest_lng: f64,
        distance_km: f64,
        estimated_time_mins: u32,
        riverbed_crossings: u32,
        road_type: []const u8,
        safe_during_rain: bool,
    } {
        _ = allocator;
        const bh = self.borehole_repo.findById(destination_borehole_id) orelse return error.NotFound;

        return .{
            .origin_lat = -18.0583,
            .origin_lng = 13.8402,
            .dest_lat = bh.lat,
            .dest_lng = bh.lng,
            .distance_km = 34.2,
            .estimated_time_mins = 58,
            .riverbed_crossings = 2,
            .road_type = "off_road_sand_track",
            .safe_during_rain = false,
        };
    }

    pub fn getDirections(
        self: LogisticsService,
        allocator: std.mem.Allocator,
        origin_lat: f64,
        origin_lng: f64,
        dest_lat: f64,
        dest_lng: f64,
    ) !GoogleMapsRouteResponse {
        return self.gmaps_adapter.calculateDirections(allocator, origin_lat, origin_lng, dest_lat, dest_lng);
    }
};
