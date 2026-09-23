const std = @import("std");

/// Certified physical, chemical, and microbiological water quality laboratory certificate.
pub const LabTest = struct {
    id: []const u8,
    borehole_id: []const u8,
    inspector_id: []const u8,
    test_date: []const u8,
    e_coli_detected: bool,
    arsenic_mg_l: f64,
    fluoride_mg_l: f64,
    is_safe_for_consumption: bool,
};

/// Monthly extraction volume compared against sustainable recharge limits.
pub const UsageQuota = struct {
    borehole_id: []const u8,
    monthly_quota_liters: u64,
    current_usage_liters: u64,
    status: []const u8,
    billing_period: []const u8,
};
