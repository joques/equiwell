const std = @import("std");
const CommunityRepository = @import("../repositories/community_repository.zig").CommunityRepository;
const CommunityRequest = @import("../models/community.zig").CommunityRequest;
const Ids = @import("../utils/ids.zig").Ids;

pub const CommunityService = struct {
    repo: CommunityRepository,

    pub fn init(repo: CommunityRepository) CommunityService {
        return .{ .repo = repo };
    }

    pub fn listCommunityRequests(self: CommunityService, allocator: std.mem.Allocator) ![]CommunityRequest {
        return self.repo.listAll(allocator);
    }

    pub fn submitRequest(
        self: CommunityService,
        allocator: std.mem.Allocator,
        community_name: []const u8,
        contact_person: []const u8,
        contact_phone: []const u8,
        issue: []const u8,
        urgency: []const u8,
    ) !struct { request_id: []const u8, status: []const u8 } {
        const id = try Ids.formatCommunityRequestId(allocator, self.repo.db.getNextCommunityReqIndex());
        const req: CommunityRequest = .{
            .id = id,
            .community_name = community_name,
            .contact_person = contact_person,
            .contact_phone = contact_phone,
            .issue = issue,
            .urgency = urgency,
            .status = "under_review",
            .submitted_at = "2026-09-23T12:00:00Z",
        };

        _ = try self.repo.create(req);
        return .{ .request_id = id, .status = "under_review" };
    }
};
