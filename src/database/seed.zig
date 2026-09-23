const std = @import("std");
const User = @import("../models/user.zig").User;
const Borehole = @import("../models/borehole.zig").Borehole;
const LabTest = @import("../models/health.zig").LabTest;
const TelemetryRecord = @import("../models/telemetry.zig").TelemetryRecord;
const MaintenanceAlert = @import("../models/telemetry.zig").MaintenanceAlert;
const CommunityRequest = @import("../models/community.zig").CommunityRequest;
const SitingSuggestion = @import("../models/ai.zig").SitingSuggestion;

pub const SeedData = struct {
    pub fn seedUsers(allocator: std.mem.Allocator, list: *std.ArrayList(User)) !void {
        // Deterministic hash of "SecurePassword123!" using PBKDF2/fallback
        const default_hash = "b926e929192ee30e047ab90fc9d1e0d811a4ccc5f0411da2047abfccc8cd8f60";

        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "USR-001"),
            .name = try allocator.dupe(u8, "Reinhold Ndevahoma"),
            .email = try allocator.dupe(u8, "rndevahoma@equiwell.nam"),
            .password_hash = try allocator.dupe(u8, default_hash),
            .role = .admin,
            .created_at = try allocator.dupe(u8, "2026-01-10T08:00:00Z"),
        });

        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "USR-002"),
            .name = try allocator.dupe(u8, "Maria Shikongo"),
            .email = try allocator.dupe(u8, "mshikongo@health.nam.gov"),
            .password_hash = try allocator.dupe(u8, default_hash),
            .role = .health_inspector,
            .created_at = try allocator.dupe(u8, "2026-02-15T09:30:00Z"),
        });

        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "USR-003"),
            .name = try allocator.dupe(u8, "Kaveto Hango"),
            .email = try allocator.dupe(u8, "khango@maint.equiwell.nam"),
            .password_hash = try allocator.dupe(u8, default_hash),
            .role = .maintenance_crew,
            .created_at = try allocator.dupe(u8, "2026-03-01T11:00:00Z"),
        });

        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "USR-004"),
            .name = try allocator.dupe(u8, "Headman Tjambiru"),
            .email = try allocator.dupe(u8, "tjambiru@kunene.gov.na"),
            .password_hash = try allocator.dupe(u8, default_hash),
            .role = .community_leader,
            .created_at = try allocator.dupe(u8, "2026-04-12T14:15:00Z"),
        });

        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "USR-005"),
            .name = try allocator.dupe(u8, "Public Observer"),
            .email = try allocator.dupe(u8, "viewer@equiwell.nam"),
            .password_hash = try allocator.dupe(u8, default_hash),
            .role = .viewer,
            .created_at = try allocator.dupe(u8, "2026-05-01T10:00:00Z"),
        });
    }

    pub fn seedBoreholes(allocator: std.mem.Allocator, list: *std.ArrayList(Borehole)) !void {
        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "BH-1001"),
            .name = try allocator.dupe(u8, "Opuwo Central Solar Well"),
            .lat = -18.0583,
            .lng = 13.8402,
            .depth_m = 110.0,
            .pump_type = .solar,
            .yield_lph = 3200,
            .status = .working,
            .water_quality = try allocator.dupe(u8, "potable"),
            .implemented_date = try allocator.dupe(u8, "2023-08-12"),
            .last_maintained = try allocator.dupe(u8, "2026-06-15"),
            .is_visible = true,
        });

        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "BH-1002"),
            .name = try allocator.dupe(u8, "Okangwati Community Well 1"),
            .lat = -18.2341,
            .lng = 13.8821,
            .depth_m = 85.0,
            .pump_type = .solar,
            .yield_lph = 1500,
            .status = .working,
            .water_quality = try allocator.dupe(u8, "potable"),
            .implemented_date = try allocator.dupe(u8, "2024-03-15"),
            .last_maintained = try allocator.dupe(u8, "2026-05-12"),
            .is_visible = true,
        });

        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "BH-1003"),
            .name = try allocator.dupe(u8, "Sesfontein Primary Borehole"),
            .lat = -19.1215,
            .lng = 13.6198,
            .depth_m = 125.0,
            .pump_type = .diesel,
            .yield_lph = 0,
            .status = .broken,
            .water_quality = try allocator.dupe(u8, "untested"),
            .implemented_date = try allocator.dupe(u8, "2021-11-20"),
            .last_maintained = try allocator.dupe(u8, "2025-10-04"),
            .is_visible = true,
        });

        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "BH-1004"),
            .name = try allocator.dupe(u8, "Epupa Falls Rural Handpump"),
            .lat = -17.0012,
            .lng = 13.2456,
            .depth_m = 45.0,
            .pump_type = .hand_pump,
            .yield_lph = 450,
            .status = .broken,
            .water_quality = try allocator.dupe(u8, "brackish"),
            .implemented_date = try allocator.dupe(u8, "2022-04-18"),
            .last_maintained = try allocator.dupe(u8, "2026-01-22"),
            .is_visible = false,
        });
    }

    pub fn seedLabTests(allocator: std.mem.Allocator, list: *std.ArrayList(LabTest)) !void {
        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "LAB-2026-081"),
            .borehole_id = try allocator.dupe(u8, "BH-1002"),
            .inspector_id = try allocator.dupe(u8, "USR-002"),
            .test_date = try allocator.dupe(u8, "2026-07-20"),
            .e_coli_detected = false,
            .arsenic_mg_l = 0.0040,
            .fluoride_mg_l = 1.10,
            .is_safe_for_consumption = true,
        });
    }

    pub fn seedAlerts(allocator: std.mem.Allocator, list: *std.ArrayList(MaintenanceAlert)) !void {
        try list.append(allocator, .{
            .borehole_id = try allocator.dupe(u8, "BH-1003"),
            .borehole_name = try allocator.dupe(u8, "Sesfontein Primary Borehole"),
            .status = try allocator.dupe(u8, "broken"),
            .issue = try allocator.dupe(u8, "Diesel engine cylinder head cracked; zero water delivery"),
            .reported_at = try allocator.dupe(u8, "2026-08-18T14:30:00Z"),
            .urgency = try allocator.dupe(u8, "critical"),
        });

        try list.append(allocator, .{
            .borehole_id = try allocator.dupe(u8, "BH-1004"),
            .borehole_name = try allocator.dupe(u8, "Epupa Falls Rural Handpump"),
            .status = try allocator.dupe(u8, "broken"),
            .issue = try allocator.dupe(u8, "Handpump mechanical lever arm sheared off"),
            .reported_at = try allocator.dupe(u8, "2026-08-17T09:15:00Z"),
            .urgency = try allocator.dupe(u8, "high"),
        });
    }

    pub fn seedCommunityRequests(allocator: std.mem.Allocator, list: *std.ArrayList(CommunityRequest)) !void {
        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "COM-REQ-101"),
            .community_name = try allocator.dupe(u8, "Otjondeka Village"),
            .contact_person = try allocator.dupe(u8, "Headman Tjambiru"),
            .contact_phone = try allocator.dupe(u8, "+264 81 555 1234"),
            .issue = try allocator.dupe(u8, "Primary well yield dropped below 100 L/h; pastoral livestock in critical distress."),
            .urgency = try allocator.dupe(u8, "critical"),
            .status = try allocator.dupe(u8, "under_review"),
            .submitted_at = try allocator.dupe(u8, "2026-08-18T11:00:00Z"),
        });
    }

    pub fn seedSuggestions(allocator: std.mem.Allocator, list: *std.ArrayList(SitingSuggestion)) !void {
        try list.append(allocator, .{
            .id = try allocator.dupe(u8, "SUG-1001"),
            .target_area = try allocator.dupe(u8, "Okangwati"),
            .status = try allocator.dupe(u8, "complete"),
            .recommended_lat = -18.2100,
            .recommended_lng = 13.8500,
            .confidence_score = 92,
            .justification = try allocator.dupe(u8, "High fracture lineament convergence and 800m proximity to underserved population."),
            .created_at = try allocator.dupe(u8, "2026-08-19T06:00:00Z"),
        });
    }
};
