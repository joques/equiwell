const std = @import("std");

pub const FactorItem = struct {
    name: []const u8,
    weight: f64,
    description: []const u8,
};

pub const GeologicalFactors = [_]FactorItem{
    .{ .name = "Lineament Density", .weight = 0.35, .description = "Fault lines and fracture zones" },
    .{ .name = "Lithology", .weight = 0.25, .description = "Rock type permeability" },
};

pub const EnvironmentalFactors = [_]FactorItem{
    .{ .name = "Rainfall Recharge", .weight = 0.20, .description = "Mean annual precipitation" },
    .{ .name = "Slope Gradient", .weight = 0.20, .description = "Terrain runoff potential" },
};
