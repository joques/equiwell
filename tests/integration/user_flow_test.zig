const std = @import("std");
const Database = @import("../../src/database/database.zig").Database;
const UserRepository = @import("../../src/repositories/user_repository.zig").UserRepository;
const UserService = @import("../../src/services/user_service.zig").UserService;
const JwtManager = @import("../../src/auth/jwt.zig").JwtManager;

test "User registration, authentication and role elevation flow" {
    const allocator = std.testing.allocator;

    const db = try Database.init(allocator);
    defer db.deinit();

    const repo = UserRepository.init(db);
    const jwt_mgr = JwtManager.init("test-jwt-secret-xyz", 3600);
    const service = UserService.init(repo, jwt_mgr);

    // Register user
    const reg_res = try service.registerUser(allocator, "Alice Test", "alice@equiwell.nam", "SecurePassword123!");
    try std.testing.expect(reg_res.user_id.len > 0);

    // Login user
    const login_res = try service.loginUser(allocator, "alice@equiwell.nam", "SecurePassword123!");
    try std.testing.expect(login_res.token.len > 0);
    try std.testing.expectEqualStrings("viewer", login_res.role);

    // Elevate role
    try std.testing.expect(service.updateUserRole(reg_res.user_id, .health_inspector));

    // Verify updated role
    const updated = service.getUserById(reg_res.user_id);
    try std.testing.expect(updated != null);
    try std.testing.expectEqual(.health_inspector, updated.?.role);
}
