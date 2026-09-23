const std = @import("std");
const Mcda = @import("../../src/domain/hydrogeology/mcda.zig").Mcda;

test "MCDA Scoring bounds" {
    const score = Mcda.calculateSuitability(1.0, 1.0, 1.0, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), score, 0.001);

    const confidence = Mcda.computeConfidenceScore(score);
    try std.testing.expectEqual(@as(u8, 100), confidence);
}
