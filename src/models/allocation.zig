const std = @import("std");

/// Demographic water stress and Gini coefficient fairness indicator across a region.
pub const AllocationMetric = struct {
    region: []const u8,
    total_population: u32,
    working_boreholes: u32,
    broken_boreholes: u32,
    average_distance_to_water_km: f64,
    water_stress_index: []const u8,
    fairness_gini_coefficient: f64,
};
