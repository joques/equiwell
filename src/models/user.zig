const std = @import("std");

/// 5-tier Role-Based Access Control hierarchy.
pub const UserRole = enum {
    admin,
    health_inspector,
    maintenance_crew,
    community_leader,
    viewer,

    pub fn toString(self: UserRole) []const u8 {
        return switch (self) {
            .admin => "admin",
            .health_inspector => "health_inspector",
            .maintenance_crew => "maintenance_crew",
            .community_leader => "community_leader",
            .viewer => "viewer",
        };
    }

    pub fn fromString(str: []const u8) ?UserRole {
        if (std.mem.eql(u8, str, "admin")) return .admin;
        if (std.mem.eql(u8, str, "health_inspector")) return .health_inspector;
        if (std.mem.eql(u8, str, "maintenance_crew")) return .maintenance_crew;
        if (std.mem.eql(u8, str, "community_leader")) return .community_leader;
        if (std.mem.eql(u8, str, "viewer")) return .viewer;
        return null;
    }
};

/// Registered user record.
pub const User = struct {
    id: []const u8,
    name: []const u8,
    email: []const u8,
    password_hash: []const u8,
    role: UserRole,
    created_at: []const u8,
};
