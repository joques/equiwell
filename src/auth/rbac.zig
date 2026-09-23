const std = @import("std");
const TokenPayload = @import("jwt.zig").TokenPayload;
const UserRole = @import("../models/user.zig").UserRole;
const Permission = @import("permissions.zig").Permission;

/// Role-Based Access Control evaluator methods.
pub const Rbac = struct {
    /// Extracts Bearer token string from raw `Authorization` header value.
    pub fn extractBearerToken(auth_header: ?[]const u8) ?[]const u8 {
        const header = auth_header orelse return null;
        if (header.len > 7 and std.ascii.startsWithIgnoreCase(header, "bearer ")) {
            return std.mem.trim(u8, header[7..], " \t");
        }
        return null;
    }

    /// Checks if user has a specific fine-grained permission.
    pub fn hasPermission(user: ?TokenPayload, permission: Permission) bool {
        const u = user orelse return false;
        return permission.isGranted(u.role);
    }

    /// Admin check helper.
    pub fn isAdmin(user: TokenPayload) bool {
        return user.role == .admin;
    }

    /// Health Inspector or Admin check helper.
    pub fn isHealthOrAdmin(user: TokenPayload) bool {
        return user.role == .admin or user.role == .health_inspector;
    }

    /// Maintenance Crew or Admin check helper.
    pub fn isMaintenanceOrAdmin(user: TokenPayload) bool {
        return user.role == .admin or user.role == .maintenance_crew;
    }

    /// Community Leader or Admin check helper.
    pub fn isLeaderOrAdmin(user: TokenPayload) bool {
        return user.role == .admin or user.role == .community_leader;
    }

    /// Non-viewer check helper.
    pub fn isNonViewer(user: TokenPayload) bool {
        return user.role != .viewer;
    }
};

// Re-exports for root/package access
pub const extractBearerToken = Rbac.extractBearerToken;
pub const isAdmin = Rbac.isAdmin;
pub const isHealthOrAdmin = Rbac.isHealthOrAdmin;
pub const isMaintenanceOrAdmin = Rbac.isMaintenanceOrAdmin;
pub const isLeaderOrAdmin = Rbac.isLeaderOrAdmin;
pub const isNonViewer = Rbac.isNonViewer;
