const std = @import("std");

pub const WaterStress = struct {
    pub fn assessWaterStress(population: u32, working_boreholes: u32) []const u8 {
        if (working_boreholes == 0) return "critical";
        const people_per_well = population / working_boreholes;
        if (people_per_well > 500) return "high";
        if (people_per_well > 250) return "moderate";
        return "low";
    }
};
