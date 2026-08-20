const std = @import("std");
const UserRole = @import("../models/user.zig").UserRole;
const TokenPayload = @import("jwt.zig").TokenPayload;

/// Extracts the raw JWT token from the HTTP Authorization header.
///
/// Supported format:
///   `Authorization: Bearer <token_string>`
///
/// Parameters:
///   - auth_header: The optional raw Authorization header value.
///
/// Returns:
///   The sliced token string if "Bearer " is matched, or `null` if absent or malformed.
pub fn extractBearerToken(auth_header: ?[]const u8) ?[]const u8 {
    const h = auth_header orelse return null;
    const trimmed = std.mem.trim(u8, h, " \t\r\n");
    if (std.ascii.startsWithIgnoreCase(trimmed, "bearer ")) {
        return std.mem.trim(u8, trimmed[7..], " \t");
    }
    return null;
}

/// Evaluates whether the authenticated user has full Administrator privileges.
pub fn isAdmin(user: TokenPayload) bool {
    return user.role == .admin;
}

/// Evaluates whether the user is authorized for Maintenance operations (Admin or Maintenance Crew).
pub fn isMaintenanceOrAdmin(user: TokenPayload) bool {
    return user.role == .admin or user.role == .maintenance_crew;
}

/// Evaluates whether the user is authorized for Water Health & Quality operations (Admin or Health Inspector).
pub fn isHealthOrAdmin(user: TokenPayload) bool {
    return user.role == .admin or user.role == .health_inspector;
}

/// Evaluates whether the user is authorized for Community Interventions (Admin or Community Leader).
pub fn isLeaderOrAdmin(user: TokenPayload) bool {
    return user.role == .admin or user.role == .community_leader;
}

/// Evaluates whether the user has non-viewer operational access.
pub fn isNonViewer(user: TokenPayload) bool {
    return user.role != .viewer;
}
