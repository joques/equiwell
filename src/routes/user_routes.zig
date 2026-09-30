const std = @import("std");
const UserService = @import("../services/user_service.zig").UserService;
const Request = @import("../server/request.zig").Request;
const Response = @import("../server/response.zig").Response;
const UserRole = @import("../models/user.zig").UserRole;
const Middleware = @import("../server/middleware.zig").Middleware;
const Validation = @import("../utils/validation.zig").Validation;

/// POST /users/register
pub fn handleRegister(service: *const UserService, req: *const Request, res: *const Response) !void {
    const parsed = std.json.parseFromSlice(struct {
        name: []const u8,
        email: []const u8,
        password: []const u8,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid registration JSON payload.");
    };
    defer parsed.deinit();

    if (!Validation.isValidString(parsed.value.name, 1, 100)) {
        return try res.badRequest("Invalid name. Name must be between 1 and 100 characters.");
    }
    if (!Validation.isValidEmail(parsed.value.email)) {
        return try res.badRequest("Invalid email address format.");
    }
    if (!Validation.isValidPassword(parsed.value.password)) {
        return try res.badRequest("Invalid password. Password must be between 8 and 128 characters.");
    }

    const result = service.registerUser(res.allocator, parsed.value.name, parsed.value.email, parsed.value.password) catch |err| {
        return switch (err) {
            error.BadRequest => try res.badRequest("Invalid email format or password under 8 characters."),
            error.Conflict => try res.badRequest("A user with this email address already exists."),
            else => try res.internalError("Registration failed."),
        };
    };

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"User registered successfully.\",\"user_id\":\"{s}\"}}",
        .{result.user_id}
    );
    defer res.allocator.free(json);

    try res.created(json);
}

/// POST /users/login
pub fn handleLogin(service: *const UserService, req: *const Request, res: *const Response) !void {
    const parsed = std.json.parseFromSlice(struct {
        email: []const u8,
        password: []const u8,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid login JSON payload.");
    };
    defer parsed.deinit();

    if (!Validation.isValidEmail(parsed.value.email) or !Validation.isValidString(parsed.value.password, 1, 128)) {
        return try res.badRequest("Invalid email or password format.");
    }

    const result = service.loginUser(res.allocator, parsed.value.email, parsed.value.password) catch |err| {
        return switch (err) {
            error.Unauthorized => try res.unauthorized("Invalid email or password credentials."),
            else => try res.internalError("Login failed."),
        };
    };

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"token\":\"{s}\",\"expires_in\":{d},\"role\":\"{s}\"}}",
        .{ result.token, result.expires_in, result.role }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// GET /users
pub fn handleListUsers(service: *const UserService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAdmin(req, res)) return;

    const users = try service.listUsers(res.allocator);
    defer res.allocator.free(users);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(res.allocator);
    try buf.appendSlice(res.allocator, "[");
    for (users, 0..) |u, i| {
        if (i > 0) try buf.appendSlice(res.allocator, ",");
        const item = try std.fmt.allocPrint(res.allocator,
            "{{\"id\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\",\"role\":\"{s}\"}}",
            .{ u.id, u.name, u.email, u.role.toString() }
        );
        defer res.allocator.free(item);
        try buf.appendSlice(res.allocator, item);
    }
    try buf.appendSlice(res.allocator, "]");

    try res.ok(buf.items);
}

/// GET /users/{id}
pub fn handleGetUserById(service: *const UserService, user_id: []const u8, req: *const Request, res: *const Response) !void {
    _ = req;
    if (!Validation.isValidString(user_id, 1, 50)) {
        return try res.badRequest("Invalid user ID parameter.");
    }
    const user = service.getUserById(user_id) orelse return try res.notFound("User not found.");

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"id\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\",\"role\":\"{s}\"}}",
        .{ user.id, user.name, user.email, user.role.toString() }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// PUT /users/{id}
pub fn handleUpdateUser(service: *const UserService, user_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Validation.isValidString(user_id, 1, 50)) {
        return try res.badRequest("Invalid user ID parameter.");
    }

    const parsed = std.json.parseFromSlice(struct {
        name: ?[]const u8 = null,
        email: ?[]const u8 = null,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid update payload.");
    };
    defer parsed.deinit();

    if (parsed.value.name == null and parsed.value.email == null) {
        return try res.badRequest("No update fields provided.");
    }

    if (parsed.value.name) |nm| {
        if (!Validation.isValidString(nm, 1, 100)) {
            return try res.badRequest("Invalid name. Name must be between 1 and 100 characters.");
        }
    }
    if (parsed.value.email) |em| {
        if (!Validation.isValidEmail(em)) {
            return try res.badRequest("Invalid email address format.");
        }
    }

    if (!service.updateUserProfile(user_id, parsed.value.name, parsed.value.email)) {
        return try res.notFound("User not found.");
    }

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"User {s} profile updated successfully.\"}}",
        .{user_id}
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// PATCH /users/{id}/role
pub fn handleUpdateUserRole(service: *const UserService, user_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAdmin(req, res)) return;
    if (!Validation.isValidString(user_id, 1, 50)) {
        return try res.badRequest("Invalid user ID parameter.");
    }

    const parsed = std.json.parseFromSlice(struct {
        role: []const u8,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid role payload.");
    };
    defer parsed.deinit();

    const new_role = UserRole.fromString(parsed.value.role) orelse {
        return try res.badRequest("Invalid role name specified.");
    };

    if (!service.updateUserRole(user_id, new_role)) {
        return try res.notFound("User not found.");
    }

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"User {s} role updated to {s}.\"}}",
        .{ user_id, new_role.toString() }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// DELETE /users/{id}
pub fn handleDeleteUser(service: *const UserService, user_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAdmin(req, res)) return;
    if (!Validation.isValidString(user_id, 1, 50)) {
        return try res.badRequest("Invalid user ID parameter.");
    }

    if (!service.deleteUser(user_id)) {
        return try res.notFound("User not found.");
    }

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"User {s} deleted successfully.\"}}",
        .{user_id}
    );
    defer res.allocator.free(json);

    try res.ok(json);
}
