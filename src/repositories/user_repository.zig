const std = @import("std");
const Database = @import("../database/database.zig").Database;
const User = @import("../models/user.zig").User;
const UserRole = @import("../models/user.zig").UserRole;

pub const UserRepository = struct {
    db: *Database,

    pub fn init(db: *Database) UserRepository {
        return .{ .db = db };
    }

    pub fn findByEmail(self: UserRepository, email: []const u8) ?User {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.users.items) |u| {
            if (std.mem.eql(u8, u.email, email)) {
                return u;
            }
        }
        return null;
    }

    pub fn findById(self: UserRepository, id: []const u8) ?User {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.users.items) |u| {
            if (std.mem.eql(u8, u.id, id)) {
                return u;
            }
        }
        return null;
    }

    pub fn listAll(self: UserRepository, allocator: std.mem.Allocator) ![]User {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const list = try allocator.alloc(User, self.db.users.items.len);
        @memcpy(list, self.db.users.items);
        return list;
    }

    pub fn create(self: UserRepository, user: User) !User {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.users.items) |u| {
            if (std.mem.eql(u8, u.email, user.email)) {
                return error.Conflict;
            }
        }

        const heap_user: User = .{
            .id = try self.db.allocator.dupe(u8, user.id),
            .name = try self.db.allocator.dupe(u8, user.name),
            .email = try self.db.allocator.dupe(u8, user.email),
            .password_hash = try self.db.allocator.dupe(u8, user.password_hash),
            .role = user.role,
            .created_at = try self.db.allocator.dupe(u8, user.created_at),
        };
        try self.db.users.append(self.db.allocator, heap_user);
        return heap_user;
    }

    pub fn update(self: UserRepository, id: []const u8, name: ?[]const u8, email: ?[]const u8) bool {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.users.items) |*u| {
            if (std.mem.eql(u8, u.id, id)) {
                if (name) |n| {
                    u.name = self.db.allocator.dupe(u8, n) catch u.name;
                }
                if (email) |e| {
                    u.email = self.db.allocator.dupe(u8, e) catch u.email;
                }
                return true;
            }
        }
        return false;
    }

    pub fn updateRole(self: UserRepository, id: []const u8, new_role: UserRole) bool {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.users.items) |*u| {
            if (std.mem.eql(u8, u.id, id)) {
                u.role = new_role;
                return true;
            }
        }
        return false;
    }

    pub fn delete(self: UserRepository, id: []const u8) bool {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.users.items, 0..) |u, i| {
            if (std.mem.eql(u8, u.id, id)) {
                _ = self.db.users.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn count(self: UserRepository) usize {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();
        return self.db.users.items.len;
    }
};
