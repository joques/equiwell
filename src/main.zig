const std = @import("std");
const Application = @import("app/application.zig").Application;

/// Application Entry Point.
/// Initializes the enterprise dependency injection container, loads configuration,
/// initializes the database, and begins listening on the configured TCP socket.
pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const app = try Application.create(allocator);
    defer app.destroy();

    try app.start();
}
