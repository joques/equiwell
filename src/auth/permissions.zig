const std = @import("std");
const UserRole = @import("../models/user.zig").UserRole;

/// Fine-grained application permission identifiers.
pub const Permission = enum {
    read_dashboard,
    read_boreholes,
    write_boreholes,
    delete_boreholes,
    read_users,
    write_users,
    manage_roles,
    record_lab_test,
    read_lab_test,
    read_quotas,
    ingest_telemetry,
    manage_maintenance,
    submit_community_request,
    read_community_requests,
    run_ai_siting,
    manage_training_data,
    read_logistics,
    calculate_routes,

    /// Evaluates if a given UserRole holds the requested permission.
    pub fn isGranted(self: Permission, role: UserRole) bool {
        return switch (self) {
            .read_dashboard, .read_boreholes => true,

            .read_users, .manage_roles, .delete_boreholes => role == .admin,

            .write_users => true, // Authenticated user can edit self; admin can edit all

            .write_boreholes => role == .admin or role == .maintenance_crew,

            .record_lab_test, .read_lab_test, .read_quotas => role == .admin or role == .health_inspector,

            .ingest_telemetry, .manage_maintenance => role == .admin or role == .maintenance_crew,

            .submit_community_request, .read_community_requests => role == .admin or role == .community_leader,

            .run_ai_siting => role != .viewer,

            .manage_training_data => role == .admin or role == .maintenance_crew,

            .read_logistics, .calculate_routes => role == .admin or role == .maintenance_crew,
        };
    }
};
