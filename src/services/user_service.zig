const std = @import("std");
const UserRepository = @import("../repositories/user_repository.zig").UserRepository;
const User = @import("../models/user.zig").User;
const UserRole = @import("../models/user.zig").UserRole;
const Password = @import("../auth/password.zig").Password;
const JwtManager = @import("../auth/jwt.zig").JwtManager;
const Ids = @import("../utils/ids.zig").Ids;
const Validation = @import("../utils/validation.zig").Validation;

pub const UserService = struct {
    repo: UserRepository,
    jwt_mgr: JwtManager,

    pub fn init(repo: UserRepository, jwt_mgr: JwtManager) UserService {
        return .{
            .repo = repo,
            .jwt_mgr = jwt_mgr,
        };
    }

    pub fn registerUser(self: UserService, allocator: std.mem.Allocator, name: []const u8, email: []const u8, password: []const u8) !struct { user_id: []const u8 } {
        if (!Validation.isValidEmail(email)) return error.BadRequest;
        if (!Validation.isValidPassword(password)) return error.BadRequest;

        if (self.repo.findByEmail(email) != null) {
            return error.Conflict;
        }

        const user_id = try Ids.formatUserId(allocator, self.repo.db.getNextUserIndex());
        const pwhash = try Password.hash(allocator, password);

        const new_user: User = .{
            .id = user_id,
            .name = name,
            .email = email,
            .password_hash = pwhash,
            .role = .viewer,
            .created_at = "2026-09-23T12:00:00Z",
        };

        _ = try self.repo.create(new_user);
        return .{ .user_id = user_id };
    }

    pub fn loginUser(self: UserService, allocator: std.mem.Allocator, email: []const u8, password: []const u8) !struct { token: []const u8, expires_in: u64, role: []const u8 } {
        const user = self.repo.findByEmail(email) orelse return error.Unauthorized;

        if (!Password.verify(password, user.password_hash)) {
            return error.Unauthorized;
        }

        const token = try self.jwt_mgr.generateToken(allocator, user.id, user.name, user.email, user.role);
        return .{
            .token = token,
            .expires_in = self.jwt_mgr.expiry_seconds,
            .role = user.role.toString(),
        };
    }

    pub fn listUsers(self: UserService, allocator: std.mem.Allocator) ![]User {
        return self.repo.listAll(allocator);
    }

    pub fn getUserById(self: UserService, id: []const u8) ?User {
        return self.repo.findById(id);
    }

    pub fn updateUserProfile(self: UserService, id: []const u8, name: ?[]const u8, email: ?[]const u8) bool {
        return self.repo.update(id, name, email);
    }

    pub fn updateUserRole(self: UserService, id: []const u8, new_role: UserRole) bool {
        return self.repo.updateRole(id, new_role);
    }

    pub fn deleteUser(self: UserService, id: []const u8) bool {
        return self.repo.delete(id);
    }
};
