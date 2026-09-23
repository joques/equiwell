const std = @import("std");
const Database = @import("../database/database.zig").Database;
const AllocationMetric = @import("../models/allocation.zig").AllocationMetric;

pub const AllocationRepository = struct {
    db: *Database,

    pub fn init(db: *Database) AllocationRepository {
        return .{ .db = db };
    }

    pub fn getMetrics(self: AllocationRepository) AllocationMetric {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        return .{
            .region = "Kunene",
            .total_population = 86856,
            .working_boreholes = 142,
            .broken_boreholes = 31,
            .average_distance_to_water_km = 4.8,
            .water_stress_index = "high",
            .fairness_gini_coefficient = 0.38,
        };
    }
};
