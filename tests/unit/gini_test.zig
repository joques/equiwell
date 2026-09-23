const std = @import("std");
const Gini = @import("../../src/domain/equity/gini.zig").Gini;

test "Gini equality and inequality tests" {
    // Perfect equality should be 0.0
    const equal_dist = [_]f64{ 5.0, 5.0, 5.0, 5.0 };
    const gini_equal = Gini.computeGini(&equal_dist);
    try std.testing.expectEqual(@as(f64, 0.0), gini_equal);

    // Unequal distribution should be > 0.0
    const unequal_dist = [_]f64{ 1.0, 2.0, 3.0, 10.0 };
    const gini_unequal = Gini.computeGini(&unequal_dist);
    try std.testing.expect(gini_unequal > 0.2 and gini_unequal < 0.6);
}
