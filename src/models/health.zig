const std = @import("std");

/// Laboratory chemical and microbiological water quality test record.
pub const LabTest = struct {
    /// Unique test certificate ID (e.g. "LAB-2026-081").
    id: []const u8,
    /// Target borehole identifier (e.g. "BH-1002").
    borehole_id: []const u8,
    /// User ID of the certified Health Inspector who recorded the test.
    inspector_id: []const u8,
    /// ISO-8601 test date.
    test_date: []const u8,
    /// Microbiological flag: presence of Escherichia coli bacteria.
    e_coli_detected: bool,
    /// Chemical measurement: dissolved arsenic concentration in milligrams per liter (mg/L).
    arsenic_mg_l: f64,
    /// Chemical measurement: dissolved fluoride concentration in milligrams per liter (mg/L).
    fluoride_mg_l: f64,
    /// Final potability determination based on national drinking water standards.
    is_safe_for_consumption: bool,
};

/// Monthly extraction quota tracking for sustainable aquifer recharge management.
pub const UsageQuota = struct {
    /// Target borehole ID.
    borehole_id: []const u8,
    /// Maximum safe monthly water extraction limit in liters.
    monthly_quota_liters: u64,
    /// Cumulative volume extracted during the current monthly billing period in liters.
    current_usage_liters: u64,
    /// Compliance status (e.g. "within_limits", "approaching_limit", "quota_exceeded").
    status: []const u8,
};
