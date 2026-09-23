const std = @import("std");

pub const TerrainFeasibility = struct {
    pub const Assessment = struct {
        is_feasible: bool,
        max_slope_gradient_degrees: f64,
        sand_entrapment_risk: []const u8,
        recommended_route_advisory: []const u8,
    };

    pub fn evaluate(vehicle_type: []const u8) Assessment {
        _ = vehicle_type;
        return .{
            .is_feasible = true,
            .max_slope_gradient_degrees = 14.2,
            .sand_entrapment_risk = "low",
            .recommended_route_advisory = "Maintain low gear on river approach",
        };
    }
};
