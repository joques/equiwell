const std = @import("std");
const Database = @import("../database/database.zig").Database;
const Borehole = @import("../models/borehole.zig").Borehole;
const BoreholeStatus = @import("../models/borehole.zig").BoreholeStatus;
const PumpType = @import("../models/borehole.zig").PumpType;

pub const BoreholeRepository = struct {
    db: *Database,

    pub fn init(db: *Database) BoreholeRepository {
        return .{ .db = db };
    }

    pub fn findById(self: BoreholeRepository, id: []const u8) ?Borehole {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.boreholes.items) |b| {
            if (std.mem.eql(u8, b.id, id)) {
                return b;
            }
        }
        return null;
    }

    pub fn listAll(self: BoreholeRepository, allocator: std.mem.Allocator, status_filter: ?BoreholeStatus, pump_filter: ?PumpType, visible_only: bool) ![]Borehole {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        var matched: std.ArrayList(Borehole) = .empty;
        defer matched.deinit(allocator);

        for (self.db.boreholes.items) |b| {
            if (visible_only and !b.is_visible) continue;
            if (status_filter) |sf| {
                if (b.status != sf) continue;
            }
            if (pump_filter) |pf| {
                if (b.pump_type != pf) continue;
            }
            try matched.append(allocator, b);
        }

        const out = try allocator.alloc(Borehole, matched.items.len);
        @memcpy(out, matched.items);
        return out;
    }

    pub fn create(self: BoreholeRepository, borehole: Borehole) !Borehole {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const heap_b: Borehole = .{
            .id = try self.db.allocator.dupe(u8, borehole.id),
            .name = try self.db.allocator.dupe(u8, borehole.name),
            .lat = borehole.lat,
            .lng = borehole.lng,
            .depth_m = borehole.depth_m,
            .pump_type = borehole.pump_type,
            .yield_lph = borehole.yield_lph,
            .status = borehole.status,
            .water_quality = try self.db.allocator.dupe(u8, borehole.water_quality),
            .implemented_date = try self.db.allocator.dupe(u8, borehole.implemented_date),
            .last_maintained = try self.db.allocator.dupe(u8, borehole.last_maintained),
            .is_visible = borehole.is_visible,
        };
        try self.db.boreholes.append(self.db.allocator, heap_b);
        return heap_b;
    }

    pub fn update(self: BoreholeRepository, id: []const u8, name: []const u8, depth_m: f64, pump_type: PumpType, yield_lph: u32, implemented_date: ?[]const u8) bool {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.boreholes.items) |*b| {
            if (std.mem.eql(u8, b.id, id)) {
                b.name = self.db.allocator.dupe(u8, name) catch b.name;
                b.depth_m = depth_m;
                b.pump_type = pump_type;
                b.yield_lph = yield_lph;
                if (implemented_date) |idate| {
                    b.implemented_date = self.db.allocator.dupe(u8, idate) catch b.implemented_date;
                }
                return true;
            }
        }
        return false;
    }

    pub fn patchStatus(self: BoreholeRepository, id: []const u8, status: ?BoreholeStatus, is_visible: ?bool) bool {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.boreholes.items) |*b| {
            if (std.mem.eql(u8, b.id, id)) {
                if (status) |st| b.status = st;
                if (is_visible) |vis| b.is_visible = vis;
                return true;
            }
        }
        return false;
    }

    pub fn delete(self: BoreholeRepository, id: []const u8) bool {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.boreholes.items, 0..) |b, i| {
            if (std.mem.eql(u8, b.id, id)) {
                _ = self.db.boreholes.orderedRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn count(self: BoreholeRepository) usize {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();
        return self.db.boreholes.items.len;
    }

    pub fn countByStatus(self: BoreholeRepository, status: BoreholeStatus) usize {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        var cnt: usize = 0;
        for (self.db.boreholes.items) |b| {
            if (b.status == status) cnt += 1;
        }
        return cnt;
    }

    pub fn getLatestImplementedDate(self: BoreholeRepository) []const u8 {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        var latest: []const u8 = "2024-03-15";
        for (self.db.boreholes.items) |b| {
            if (b.implemented_date.len > 0 and std.mem.order(u8, b.implemented_date, latest) == .gt) {
                latest = b.implemented_date;
            }
        }
        return latest;
    }
};
