const std = @import("std");
const Application = @import("../../src/app/application.zig").Application;

test "Application container initialization and teardown" {
    const allocator = std.testing.allocator;

    const app = try Application.create(allocator);
    defer app.destroy();

    // Verify application state
    try std.testing.expectEqual(@as(u16, 8080), app.config.port);
    try std.testing.expect(app.db.boreholes.items.len >= 4);
    try std.testing.expect(app.db.users.items.len >= 5);
}
