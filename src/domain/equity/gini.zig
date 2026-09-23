const std = @import("std");

/// Mathematical Gini coefficient inequality index calculation.
pub const Gini = struct {
    /// Computes the Gini coefficient given an array of demographic distance or water allocation values.
    /// Result ranges from 0.0 (perfect equality) to 1.0 (maximal inequality).
    pub fn computeGini(values: []const f64) f64 {
        if (values.len == 0) return 0.0;
        if (values.len == 1) return 0.0;

        var sum_abs_diff: f64 = 0.0;
        var total_sum: f64 = 0.0;

        for (values) |yi| {
            total_sum += yi;
            for (values) |yj| {
                sum_abs_diff += @abs(yi - yj);
            }
        }

        if (total_sum == 0.0) return 0.0;

        const n: f64 = @floatFromInt(values.len);
        return sum_abs_diff / (2.0 * n * total_sum);
    }
};
