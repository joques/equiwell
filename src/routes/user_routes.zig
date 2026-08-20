const std = @import("std");
const DataStore = @import("../db/store.zig").DataStore;
const User = @import("../models/user.zig").User;
const UserRole = @import("../models/user.zig").UserRole;
const password_auth = @import("../auth/password.zig");
const jwt = @import("../auth/jwt.zig");
const http_util = @import("../utils/http_util.zig");

/// Handles `POST /users/register` - Registers a new user account (default role: `viewer`).
pub fn handleRegister(allocator: std.mem.Allocator, store: *DataStore, body: []const u8, response: *const http_util.Response) !void {
    const parsed = std.json.parseFromSlice(struct {
        name: []const u8,
        email: []const u8,
        password: []const u8,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON registration payload");
    };
    defer parsed.deinit();

    if (store.findUserByEmail(parsed.value.email) != null) {
        return try http_util.sendBadRequest(response, "A user with this email address already exists");
    }

    const hashed = try password_auth.hashPassword(store.allocator, parsed.value.password);
    const new_id = try std.fmt.allocPrint(store.allocator, "USR-{0d:0>3}", .{store.users.items.len + 1});

    const user: User = .{
        .id = new_id,
        .name = try store.allocator.dupe(u8, parsed.value.name),
        .email = try store.allocator.dupe(u8, parsed.value.email),
        .password_hash = hashed,
        .role = .viewer,
        .created_at = "2026-08-19T12:00:00Z",
    };

    try store.addUser(user);

    const res_json = try std.fmt.allocPrint(allocator, "{{\"message\":\"User registered successfully.\",\"user_id\":\"{s}\"}}", .{new_id});
    defer allocator.free(res_json);

    try http_util.sendCreated(response, res_json);
}

/// Handles `POST /users/login` - Authenticates user credentials and issues an HMAC-SHA256 JWT Bearer token.
pub fn handleLogin(allocator: std.mem.Allocator, store: *DataStore, body: []const u8, response: *const http_util.Response) !void {
    const parsed = std.json.parseFromSlice(struct {
        email: []const u8,
        password: []const u8,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON login payload");
    };
    defer parsed.deinit();

    const user = store.findUserByEmail(parsed.value.email) orelse {
        return try http_util.sendUnauthorized(response, "Invalid email or password");
    };

    if (!password_auth.verifyPassword(parsed.value.password, user.password_hash)) {
        return try http_util.sendUnauthorized(response, "Invalid email or password");
    }

    const token = try jwt.generateToken(allocator, user.id, user.name, user.email, user.role);
    defer allocator.free(token);

    const res_json = try std.fmt.allocPrint(allocator, "{{\"token\":\"{s}\",\"expires_in\":3600,\"role\":\"{s}\"}}", .{ token, user.role.toString() });
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}

/// Handles `GET /users` - Lists all registered user accounts (Restricted to `admin`).
pub fn handleListUsers(allocator: std.mem.Allocator, store: *DataStore, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin) {
        return try http_util.sendForbidden(response, "Only Administrators are authorized to view the complete user directory.");
    }

    store.mutex.lock();
    defer store.mutex.unlock();

    var list = std.ArrayList(u8).empty;
    defer list.deinit(allocator);

    try list.appendSlice(allocator, "[");
    for (store.users.items, 0..) |u, i| {
        if (i > 0) try list.appendSlice(allocator, ",");
        const item_str = try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\",\"role\":\"{s}\"}}", .{ u.id, u.name, u.email, u.role.toString() });
        defer allocator.free(item_str);
        try list.appendSlice(allocator, item_str);
    }
    try list.appendSlice(allocator, "]");

    try http_util.sendOk(response, list.items);
}

/// Handles `GET /users/{id}` - Retrieves individual user profile details.
pub fn handleGetUserById(allocator: std.mem.Allocator, store: *DataStore, id: []const u8, response: *const http_util.Response) !void {
    const user = store.findUserById(id) orelse {
        return try http_util.sendNotFound(response, "User not found");
    };

    const res_json = try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\",\"role\":\"{s}\"}}", .{ user.id, user.name, user.email, user.role.toString() });
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}

/// Handles `PUT /users/{id}` - Updates a user's display name and email address.
pub fn handleUpdateUser(allocator: std.mem.Allocator, store: *DataStore, id: []const u8, body: []const u8, response: *const http_util.Response) !void {
    const parsed = std.json.parseFromSlice(struct {
        name: []const u8,
        email: []const u8,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON update payload");
    };
    defer parsed.deinit();

    const updated = try store.updateUser(id, parsed.value.name, parsed.value.email);
    if (!updated) {
        return try http_util.sendNotFound(response, "User not found");
    }

    const res_json = try std.fmt.allocPrint(allocator, "{{\"message\":\"User {s} profile updated successfully.\"}}", .{id});
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}

/// Handles `PATCH /users/{id}/role` - Modifies or elevates a user's assigned RBAC role (Restricted to `admin`).
pub fn handleUpdateUserRole(allocator: std.mem.Allocator, store: *DataStore, id: []const u8, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin) {
        return try http_util.sendForbidden(response, "Only Administrators can modify user security roles.");
    }

    const parsed = std.json.parseFromSlice(struct {
        role: []const u8,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON role payload");
    };
    defer parsed.deinit();

    const new_role = UserRole.fromString(parsed.value.role) orelse {
        return try http_util.sendBadRequest(response, "Invalid role name. Must be: admin, health_inspector, maintenance_crew, community_leader, or viewer.");
    };

    const updated = store.updateUserRole(id, new_role);
    if (!updated) {
        return try http_util.sendNotFound(response, "User not found");
    }

    const res_json = try std.fmt.allocPrint(allocator, "{{\"message\":\"User {s} role updated to {s}.\"}}", .{ id, new_role.toString() });
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}

/// Handles `DELETE /users/{id}` - Permanently removes a user account from the system (Restricted to `admin`).
pub fn handleDeleteUser(allocator: std.mem.Allocator, store: *DataStore, id: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin) {
        return try http_util.sendForbidden(response, "Only Administrators can delete user accounts.");
    }

    const deleted = store.deleteUser(id);
    if (!deleted) {
        return try http_util.sendNotFound(response, "User not found");
    }

    const res_json = try std.fmt.allocPrint(allocator, "{{\"message\":\"User {s} deleted successfully.\"}}", .{id});
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}
