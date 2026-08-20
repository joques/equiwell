const std = @import("std");

/// 5-tier Role-Based Access Control (RBAC) user roles.
pub const UserRole = enum {
    /// Full access across all system entities, user elevation, and borehole deletion.
    admin,
    /// Access to certified laboratory water quality tests and usage quotas.
    health_inspector,
    /// Access to IoT telemetry ingestion, logistics routing, and maintenance alerts.
    maintenance_crew,
    /// Access to submit and review community emergency water requests and siting suggestions.
    community_leader,
    /// Public read-only access to dashboard summaries and visible boreholes.
    viewer,

    /// Converts the enum variant to its standard lowercase string representation.
    pub fn toString(self: UserRole) []const u8 {
        return switch (self) {
            .admin => "admin",
            .health_inspector => "health_inspector",
            .maintenance_crew => "maintenance_crew",
            .community_leader => "community_leader",
            .viewer => "viewer",
        };
    }

    /// Parses a string into a UserRole enum variant.
    pub fn fromString(str: []const u8) ?UserRole {
        if (std.mem.eql(u8, str, "admin")) return .admin;
        if (std.mem.eql(u8, str, "health_inspector")) return .health_inspector;
        if (std.mem.eql(u8, str, "maintenance_crew")) return .maintenance_crew;
        if (std.mem.eql(u8, str, "community_leader")) return .community_leader;
        if (std.mem.eql(u8, str, "viewer")) return .viewer;
        return null;
    }
};

/// Core User entity representing an authenticated actor in the EquiWell platform.
pub const User = struct {
    /// Unique user identifier (e.g. "USR-001").
    id: []const u8,
    /// Full display name of the user.
    name: []const u8,
    /// Primary email address used for login authentication.
    email: []const u8,
    /// SHA-256 password hash in lowercase hexadecimal format.
    password_hash: []const u8,
    /// Assigned RBAC role.
    role: UserRole,
    /// ISO-8601 timestamp of user account creation.
    created_at: []const u8,
};
