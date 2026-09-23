const std = @import("std");
const Database = @import("../../src/database/database.zig").Database;
const BoreholeRepository = @import("../../src/repositories/borehole_repository.zig").BoreholeRepository;
const BoreholeService = @import("../../src/services/borehole_service.zig").BoreholeService;

test "Borehole Service and Repository integration lifecycle" {
    const allocator = std.testing.allocator;

    const db = try Database.init(allocator);
    defer db.deinit();

    const repo = BoreholeRepository.init(db);
    const service = BoreholeService.init(repo);

    // Initial count should be seeded
    const list = try service.getBoreholes(allocator, null, null, true);
    defer allocator.free(list);
    try std.testing.expect(list.len >= 4);

    // Create a new borehole
    const res = try service.createBorehole(
        allocator,
        "Test Integration Well",
        -18.1234,
        13.5678,
        90.0,
        .solar,
        2500,
        "2026-09-23",
    );
    try std.testing.expect(res.borehole_id.len > 0);

    // Verify retrieval
    const bh = service.getBoreholeById(res.borehole_id);
    try std.testing.expect(bh != null);
    try std.testing.expectEqualStrings("Test Integration Well", bh.?.name);
}
