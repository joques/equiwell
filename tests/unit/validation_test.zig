const std = @import("std");
const Validation = @import("../../src/utils/validation.zig").Validation;

test "Input Validation helper tests" {
    try std.testing.expect(Validation.isValidEmail("user@equiwell.nam"));
    try std.testing.expect(!Validation.isValidEmail("invalid-email"));
    try std.testing.expect(!Validation.isValidEmail("@nodomain"));

    try std.testing.expect(Validation.isValidPassword("Pass1234!"));
    try std.testing.expect(!Validation.isValidPassword("short"));

    try std.testing.expect(Validation.isValidCoordinates(-18.0583, 13.8402));
    try std.testing.expect(!Validation.isValidCoordinates(99.0, 13.0));
}
