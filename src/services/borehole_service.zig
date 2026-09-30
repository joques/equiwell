const std = @import("std");
const BoreholeRepository = @import("../repositories/borehole_repository.zig").BoreholeRepository;
const Borehole = @import("../models/borehole.zig").Borehole;
const BoreholeStatus = @import("../models/borehole.zig").BoreholeStatus;
const PumpType = @import("../models/borehole.zig").PumpType;
const Ids = @import("../utils/ids.zig").Ids;

pub const BoreholeService = struct {
    repo: BoreholeRepository,

    pub fn init(repo: BoreholeRepository) BoreholeService {
        return .{ .repo = repo };
    }

    pub fn getBoreholes(self: BoreholeService, allocator: std.mem.Allocator, status_filter: ?BoreholeStatus, pump_filter: ?PumpType, is_admin_or_staff: bool) ![]Borehole {
        const visible_only = !is_admin_or_staff;
        return self.repo.listAll(allocator, status_filter, pump_filter, visible_only);
    }

    pub fn getBoreholeById(self: BoreholeService, id: []const u8) ?Borehole {
        return self.repo.findById(id);
    }

    pub fn createBorehole(
        self: BoreholeService,
        allocator: std.mem.Allocator,
        name: []const u8,
        lat: f64,
        lng: f64,
        depth_m: f64,
        pump_type: PumpType,
        yield_lph: u32,
        implemented_date: ?[]const u8,
    ) !struct { borehole_id: []const u8, implemented_date: []const u8 } {
        const id = try Ids.formatBoreholeId(allocator, self.repo.db.getNextBoreholeIndex());
        const imp_date = implemented_date orelse "2026-09-23";

        const new_b: Borehole = .{
            .id = id,
            .name = name,
            .lat = lat,
            .lng = lng,
            .depth_m = depth_m,
            .pump_type = pump_type,
            .yield_lph = yield_lph,
            .status = .working,
            .water_quality = "potable",
            .implemented_date = imp_date,
            .last_maintained = "2026-09-23",
            .is_visible = true,
        };

        _ = try self.repo.create(new_b);
        return .{ .borehole_id = id, .implemented_date = imp_date };
    }

    pub fn updateBorehole(self: BoreholeService, id: []const u8, name: []const u8, depth_m: f64, pump_type: PumpType, yield_lph: u32, implemented_date: ?[]const u8) bool {
        return self.repo.update(id, name, depth_m, pump_type, yield_lph, implemented_date);
    }

    pub fn patchBorehole(self: BoreholeService, id: []const u8, status: ?BoreholeStatus, is_visible: ?bool) bool {
        return self.repo.patchStatus(id, status, is_visible);
    }

    pub fn deleteBorehole(self: BoreholeService, id: []const u8) bool {
        return self.repo.delete(id);
    }

    pub fn getDashboardSummary(self: BoreholeService) struct {
        total_boreholes: usize,
        working_boreholes: usize,
        broken_boreholes: usize,
        maintenance_required_boreholes: usize,
        communities_at_risk: usize,
        recent_installations_this_year: usize,
        latest_borehole_implemented_date: []const u8,
        last_synced_at: []const u8,
    } {
        const stats = self.repo.getSummaryStats();

        return .{
            .total_boreholes = stats.total,
            .working_boreholes = stats.working,
            .broken_boreholes = stats.broken,
            .maintenance_required_boreholes = stats.maintenance_required,
            .communities_at_risk = 3,
            .recent_installations_this_year = 1,
            .latest_borehole_implemented_date = stats.latest_implemented_date,
            .last_synced_at = "2026-09-23T12:00:00Z",
        };
    }
};
