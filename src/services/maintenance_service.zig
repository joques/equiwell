const std = @import("std");
const TelemetryRepository = @import("../repositories/telemetry_repository.zig").TelemetryRepository;
const BoreholeRepository = @import("../repositories/borehole_repository.zig").BoreholeRepository;
const MaintenanceAlert = @import("../models/telemetry.zig").MaintenanceAlert;
const YieldHistoryEntry = @import("../models/telemetry.zig").YieldHistoryEntry;

pub const MaintenanceService = struct {
    telemetry_repo: TelemetryRepository,
    borehole_repo: BoreholeRepository,

    pub fn init(telemetry_repo: TelemetryRepository, borehole_repo: BoreholeRepository) MaintenanceService {
        return .{
            .telemetry_repo = telemetry_repo,
            .borehole_repo = borehole_repo,
        };
    }

    pub fn listAlerts(self: MaintenanceService, allocator: std.mem.Allocator) ![]MaintenanceAlert {
        return self.telemetry_repo.listAlerts(allocator);
    }

    pub fn getYieldHistory(self: MaintenanceService, allocator: std.mem.Allocator, borehole_id: []const u8) ![]YieldHistoryEntry {
        if (self.borehole_repo.findById(borehole_id) == null) {
            return error.NotFound;
        }

        const entries = try allocator.alloc(YieldHistoryEntry, 3);
        entries[0] = .{ .year = 2024, .average_yield_lph = 1600 };
        entries[1] = .{ .year = 2025, .average_yield_lph = 1550 };
        entries[2] = .{ .year = 2026, .average_yield_lph = 1500 };
        return entries;
    }
};
