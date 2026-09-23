const std = @import("std");
const Database = @import("../database/database.zig").Database;
const CommunityRequest = @import("../models/community.zig").CommunityRequest;

pub const CommunityRepository = struct {
    db: *Database,

    pub fn init(db: *Database) CommunityRepository {
        return .{ .db = db };
    }

    pub fn listAll(self: CommunityRepository, allocator: std.mem.Allocator) ![]CommunityRequest {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const out = try allocator.alloc(CommunityRequest, self.db.community_requests.items.len);
        @memcpy(out, self.db.community_requests.items);
        return out;
    }

    pub fn create(self: CommunityRepository, req: CommunityRequest) !CommunityRequest {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const heap_req: CommunityRequest = .{
            .id = try self.db.allocator.dupe(u8, req.id),
            .community_name = try self.db.allocator.dupe(u8, req.community_name),
            .contact_person = try self.db.allocator.dupe(u8, req.contact_person),
            .contact_phone = try self.db.allocator.dupe(u8, req.contact_phone),
            .issue = try self.db.allocator.dupe(u8, req.issue),
            .urgency = try self.db.allocator.dupe(u8, req.urgency),
            .status = try self.db.allocator.dupe(u8, req.status),
            .submitted_at = try self.db.allocator.dupe(u8, req.submitted_at),
        };
        try self.db.community_requests.append(self.db.allocator, heap_req);
        return heap_req;
    }
};
