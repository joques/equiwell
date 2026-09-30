const std = @import("std");
const TelemetryRepository = @import("../repositories/telemetry_repository.zig").TelemetryRepository;
const BoreholeRepository = @import("../repositories/borehole_repository.zig").BoreholeRepository;
const TelemetryRecord = @import("../models/telemetry.zig").TelemetryRecord;
const MaintenanceAlert = @import("../models/telemetry.zig").MaintenanceAlert;
const Ids = @import("../utils/ids.zig").Ids;

pub const TelemetryService = struct {
    telemetry_repo: TelemetryRepository,
    borehole_repo: BoreholeRepository,

    pub fn init(telemetry_repo: TelemetryRepository, borehole_repo: BoreholeRepository) TelemetryService {
        return .{
            .telemetry_repo = telemetry_repo,
            .borehole_repo = borehole_repo,
        };
    }

    pub fn ingestTelemetry(
        self: TelemetryService,
        allocator: std.mem.Allocator,
        borehole_id: []const u8,
        drawdown_m: f64,
        recovery_time_mins: u32,
        solar_battery_level: u8,
        flow_rate_lpm: f64,
    ) !struct { telemetry_id: []const u8, borehole_id: []const u8 } {
        if (self.borehole_repo.findById(borehole_id) == null) {
            return error.NotFound;
        }

        const id = try Ids.formatTelemetryId(allocator, self.telemetry_repo.db.getNextTelemetryIndex());
        const rec: TelemetryRecord = .{
            .id = id,
            .borehole_id = borehole_id,
            .drawdown_m = drawdown_m,
            .recovery_time_mins = recovery_time_mins,
            .solar_battery_level = solar_battery_level,
            .flow_rate_lpm = flow_rate_lpm,
            .timestamp = "2026-09-23T12:00:00Z",
        };

        _ = try self.telemetry_repo.createTelemetry(rec);

        // Auto-generate alert if severe pump anomaly detected
        if (solar_battery_level < 10 or flow_rate_lpm <= 0.0) {
            if (self.borehole_repo.findById(borehole_id)) |bh| {
                try self.telemetry_repo.createAlert(.{
                    .borehole_id = borehole_id,
                    .borehole_name = bh.name,
                    .status = "broken",
                    .issue = "Critical telemetry failure detected by IoT sensor",
                    .reported_at = "2026-09-23T12:00:00Z",
                    .urgency = "critical",
                });
            }
        }

        return .{ .telemetry_id = id, .borehole_id = borehole_id };
    }
};
