const std = @import("std");
const Password = @import("../../src/auth/password.zig").Password;
const JwtManager = @import("../../src/auth/jwt.zig").JwtManager;
const UserRole = @import("../../src/models/user.zig").UserRole;

test "Password PBKDF2 hashing verification" {
    const allocator = std.testing.allocator;
    const pwd = "SecurePassword123!";

    const hashed = try Password.hash(allocator, pwd);
    defer allocator.free(hashed);

    try std.testing.expect(Password.verify(pwd, hashed));
    try std.testing.expect(!Password.verify("WrongPassword999", hashed));
}

test "JWT token generation and verification lifecycle" {
    const allocator = std.testing.allocator;
    const jwt_mgr = JwtManager.init("test-secret-key-123", 3600);

    const token = try jwt_mgr.generateToken(
        allocator,
        "USR-001",
        "Reinhold Ndevahoma",
        "rndevahoma@equiwell.nam",
        .admin,
    );
    defer allocator.free(token);

    var payload = jwt_mgr.verifyToken(allocator, token);
    try std.testing.expect(payload != null);
    if (payload) |*p| {
        defer p.deinit(allocator);
        try std.testing.expectEqualStrings("USR-001", p.sub);
        try std.testing.expectEqual(UserRole.admin, p.role);
    }
}
