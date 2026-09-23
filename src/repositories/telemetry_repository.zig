const std = @import("std");
const Database = @import("../database/database.zig").Database;
const TelemetryRecord = @import("../models/telemetry.zig").TelemetryRecord;
const MaintenanceAlert = @import("../models/telemetry.zig").MaintenanceAlert;

pub const TelemetryRepository = struct {
    db: *Database,

    pub fn init(db: *Database) TelemetryRepository {
        return .{ .db = db };
    }

    pub fn createTelemetry(self: TelemetryRepository, rec: TelemetryRecord) !TelemetryRecord {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const heap_rec: TelemetryRecord = .{
            .id = try self.db.allocator.dupe(u8, rec.id),
            .borehole_id = try self.db.allocator.dupe(u8, rec.borehole_id),
            .drawdown_m = rec.drawdown_m,
            .recovery_time_mins = rec.recovery_time_mins,
            .solar_battery_level = rec.solar_battery_level,
            .flow_rate_lpm = rec.flow_rate_lpm,
            .timestamp = try self.db.allocator.dupe(u8, rec.timestamp),
        };
        try self.db.telemetry_records.append(self.db.allocator, heap_rec);
        return heap_rec;
    }

    pub fn listAlerts(self: TelemetryRepository, allocator: std.mem.Allocator) ![]MaintenanceAlert {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const out = try allocator.alloc(MaintenanceAlert, self.db.maintenance_alerts.items.len);
        @memcpy(out, self.db.maintenance_alerts.items);
        return out;
    }

    pub fn createAlert(self: TelemetryRepository, alert: MaintenanceAlert) !void {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const heap_alert: MaintenanceAlert = .{
            .borehole_id = try self.db.allocator.dupe(u8, alert.borehole_id),
            .borehole_name = try self.db.allocator.dupe(u8, alert.borehole_name),
            .status = try self.db.allocator.dupe(u8, alert.status),
            .issue = try self.db.allocator.dupe(u8, alert.issue),
            .reported_at = try self.db.allocator.dupe(u8, alert.reported_at),
            .urgency = try self.db.allocator.dupe(u8, alert.urgency),
        };
        try self.db.maintenance_alerts.append(self.db.allocator, heap_alert);
    }
};
