const std = @import("std");
const LabRepository = @import("../repositories/lab_repository.zig").LabRepository;
const BoreholeRepository = @import("../repositories/borehole_repository.zig").BoreholeRepository;
const LabTest = @import("../models/health.zig").LabTest;
const UsageQuota = @import("../models/health.zig").UsageQuota;
const Ids = @import("../utils/ids.zig").Ids;

pub const HealthService = struct {
    lab_repo: LabRepository,
    borehole_repo: BoreholeRepository,

    pub fn init(lab_repo: LabRepository, borehole_repo: BoreholeRepository) HealthService {
        return .{
            .lab_repo = lab_repo,
            .borehole_repo = borehole_repo,
        };
    }

    pub fn recordLabTest(
        self: HealthService,
        allocator: std.mem.Allocator,
        borehole_id: []const u8,
        inspector_id: []const u8,
        test_date: []const u8,
        e_coli_detected: bool,
        arsenic_mg_l: f64,
        fluoride_mg_l: f64,
        is_safe: bool,
    ) !struct { test_id: []const u8, borehole_id: []const u8 } {
        if (self.borehole_repo.findById(borehole_id) == null) {
            return error.NotFound;
        }

        const id = try Ids.formatLabTestId(allocator, 2);
        const new_test: LabTest = .{
            .id = id,
            .borehole_id = borehole_id,
            .inspector_id = inspector_id,
            .test_date = test_date,
            .e_coli_detected = e_coli_detected,
            .arsenic_mg_l = arsenic_mg_l,
            .fluoride_mg_l = fluoride_mg_l,
            .is_safe_for_consumption = is_safe,
        };

        _ = try self.lab_repo.create(new_test);
        return .{ .test_id = id, .borehole_id = borehole_id };
    }

    pub fn getLabTests(self: HealthService, allocator: std.mem.Allocator, borehole_id: []const u8) ![]LabTest {
        if (self.borehole_repo.findById(borehole_id) == null) {
            return error.NotFound;
        }
        return self.lab_repo.listByBoreholeId(allocator, borehole_id);
    }

    pub fn getUsageQuota(self: HealthService, borehole_id: []const u8) !UsageQuota {
        if (self.borehole_repo.findById(borehole_id) == null) {
            return error.NotFound;
        }
        return .{
            .borehole_id = borehole_id,
            .monthly_quota_liters = 150000,
            .current_usage_liters = 125000,
            .status = "within_limits",
            .billing_period = "2026-08",
        };
    }
};
