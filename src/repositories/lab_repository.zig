const std = @import("std");
const Database = @import("../database/database.zig").Database;
const LabTest = @import("../models/health.zig").LabTest;

pub const LabRepository = struct {
    db: *Database,

    pub fn init(db: *Database) LabRepository {
        return .{ .db = db };
    }

    pub fn listByBoreholeId(self: LabRepository, allocator: std.mem.Allocator, borehole_id: []const u8) ![]LabTest {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        var matched: std.ArrayList(LabTest) = .empty;
        defer matched.deinit(allocator);

        for (self.db.lab_tests.items) |t| {
            if (std.mem.eql(u8, t.borehole_id, borehole_id)) {
                try matched.append(allocator, t);
            }
        }

        const out = try allocator.alloc(LabTest, matched.items.len);
        @memcpy(out, matched.items);
        return out;
    }

    pub fn create(self: LabRepository, lab_test: LabTest) !LabTest {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const heap_t: LabTest = .{
            .id = try self.db.allocator.dupe(u8, lab_test.id),
            .borehole_id = try self.db.allocator.dupe(u8, lab_test.borehole_id),
            .inspector_id = try self.db.allocator.dupe(u8, lab_test.inspector_id),
            .test_date = try self.db.allocator.dupe(u8, lab_test.test_date),
            .e_coli_detected = lab_test.e_coli_detected,
            .arsenic_mg_l = lab_test.arsenic_mg_l,
            .fluoride_mg_l = lab_test.fluoride_mg_l,
            .is_safe_for_consumption = lab_test.is_safe_for_consumption,
        };
        try self.db.lab_tests.append(self.db.allocator, heap_t);
        return heap_t;
    }
};
