const std = @import("std");

/// Multi-Criteria Decision Analysis scoring for groundwater potential.
pub const Mcda = struct {
    pub fn calculateSuitability(lineament_score: f64, lithology_score: f64, rainfall_score: f64, slope_score: f64) f64 {
        // Weighted linear combination
        return (lineament_score * 0.35) + (lithology_score * 0.25) + (rainfall_score * 0.20) + (slope_score * 0.20);
    }

    pub fn computeConfidenceScore(suitability: f64) u8 {
        const clamped = @max(0.0, @min(1.0, suitability));
        return @intFromFloat(clamped * 100.0);
    }
};
