const std = @import("std");

/// Global configuration exports.
pub const config = @import("config.zig");

/// Domain data models.
pub const models = struct {
    pub const user = @import("models/user.zig");
    pub const borehole = @import("models/borehole.zig");
    pub const health = @import("models/health.zig");
    pub const telemetry = @import("models/telemetry.zig");
    pub const allocation = @import("models/allocation.zig");
    pub const logistics = @import("models/logistics.zig");
    pub const ai_siting = @import("models/ai_siting.zig");
};

/// Authentication & authorization security services.
pub const auth = struct {
    pub const password = @import("auth/password.zig");
    pub const jwt = @import("auth/jwt.zig");
    pub const rbac = @import("auth/rbac.zig");
};

/// Thread-safe in-memory database persistence.
pub const db = struct {
    pub const store = @import("db/store.zig");
};

/// HTTP utilities and response helpers.
pub const utils = struct {
    pub const http = @import("utils/http_util.zig");
};

// =========================================================================
// UNIT TESTS
// =========================================================================

test "JWT generation and verification" {
    const allocator = std.testing.allocator;

    // 1. Generate JWT Token
    const token = try auth.jwt.generateToken(
        allocator,
        "USR-001",
        "Reinhold Ndevahoma",
        "rndevahoma@equiwell.nam",
        .admin,
    );
    defer allocator.free(token);

    try std.testing.expect(token.len > 0);

    // 2. Verify and Parse Token Payload
    var payload = auth.jwt.verifyToken(allocator, token);
    try std.testing.expect(payload != null);
    if (payload) |*p| {
        defer p.deinit(allocator);
        try std.testing.expectEqualStrings("USR-001", p.sub);
        try std.testing.expectEqualStrings("Reinhold Ndevahoma", p.name);
        try std.testing.expectEqualStrings("rndevahoma@equiwell.nam", p.email);
        try std.testing.expectEqual(models.user.UserRole.admin, p.role);
    }
}

test "DataStore initialization and lookup" {
    const allocator = std.testing.allocator;

    // 1. Initialize In-Memory Store
    const store = try db.store.DataStore.init(allocator);
    defer store.deinit();

    // 2. Lookup Seeded Administrator
    const user = store.findUserByEmail("rndevahoma@equiwell.nam");
    try std.testing.expect(user != null);
    if (user) |u| {
        try std.testing.expectEqualStrings("USR-001", u.id);
        try std.testing.expectEqual(models.user.UserRole.admin, u.role);
    }

    // 3. Lookup Seeded Borehole with Commissioning Date
    const borehole = store.findBoreholeById("BH-1002");
    try std.testing.expect(borehole != null);
    if (borehole) |bh| {
        try std.testing.expectEqualStrings("Okangwati Community Well 1", bh.name);
        try std.testing.expectEqualStrings("2024-03-15", bh.implemented_date);
    }
}
