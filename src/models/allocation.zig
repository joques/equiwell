const std = @import("std");

/// Formal water emergency or new infrastructure request submitted by traditional leaders.
pub const CommunityRequest = struct {
    /// Unique request tracking ID (e.g. "COM-REQ-101").
    id: []const u8,
    /// Name of village or traditional community.
    community_name: []const u8,
    /// Traditional leader or village representative name.
    contact_person: []const u8,
    /// Phone number of the contact person.
    contact_phone: []const u8,
    /// Description of the water crisis or dry-up condition.
    issue: []const u8,
    /// Urgency classification ("critical", "high", "medium").
    urgency: []const u8,
    /// Administrative processing state ("under_review", "approved", "dispatched", "completed").
    status: []const u8,
    /// ISO-8601 submission timestamp.
    submitted_at: []const u8,
};

/// Regional water parity indicators and demographic stress metrics.
pub const AllocationMetric = struct {
    /// Administrative region name (e.g. "Kunene").
    region: []const u8,
    /// Estimated rural population count.
    total_population: u32,
    /// Number of active functioning boreholes.
    working_boreholes: u32,
    /// Number of decommissioned or broken boreholes.
    broken_boreholes: u32,
    /// Average distance residents must travel to access clean water in kilometers.
    average_distance_to_water_km: f64,
    /// Water stress severity level ("low", "moderate", "high", "severe").
    water_stress_index: []const u8,
    /// Gini coefficient measuring inequality in regional borehole distribution (0 = perfect equality).
    fairness_gini_coefficient: f64,
};
