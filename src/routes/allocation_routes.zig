const std = @import("std");
const AllocationService = @import("../services/allocation_service.zig").AllocationService;
const CommunityService = @import("../services/community_service.zig").CommunityService;
const Request = @import("../server/request.zig").Request;
const Response = @import("../server/response.zig").Response;
const Middleware = @import("../server/middleware.zig").Middleware;
const Rbac = @import("../auth/rbac.zig").Rbac;
const Validation = @import("../utils/validation.zig").Validation;

/// GET /allocation-metrics
pub fn handleGetAllocationMetrics(service: *const AllocationService, req: *const Request, res: *const Response) !void {
    _ = req;
    const m = service.getAllocationMetrics();

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"region\":\"{s}\",\"total_population\":{d},\"working_boreholes\":{d},\"broken_boreholes\":{d},\"average_distance_to_water_km\":{d:.1},\"water_stress_index\":\"{s}\",\"fairness_gini_coefficient\":{d:.2}}}",
        .{ m.region, m.total_population, m.working_boreholes, m.broken_boreholes, m.average_distance_to_water_km, m.water_stress_index, m.fairness_gini_coefficient }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// GET /community-requests
pub fn handleGetCommunityRequests(service: *const CommunityService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isLeaderOrAdmin(req.user.?)) {
        return try res.forbidden("Only Community Leaders or Admins can view community requests.");
    }

    const requests = try service.listCommunityRequests(res.allocator);
    defer res.allocator.free(requests);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(res.allocator);
    try buf.appendSlice(res.allocator, "[");
    for (requests, 0..) |r, i| {
        if (i > 0) try buf.appendSlice(res.allocator, ",");
        const item = try std.fmt.allocPrint(res.allocator,
            "{{\"id\":\"{s}\",\"community_name\":\"{s}\",\"contact_person\":\"{s}\",\"contact_phone\":\"{s}\",\"issue\":\"{s}\",\"urgency\":\"{s}\",\"status\":\"{s}\",\"submitted_at\":\"{s}\"}}",
            .{ r.id, r.community_name, r.contact_person, r.contact_phone, r.issue, r.urgency, r.status, r.submitted_at }
        );
        defer res.allocator.free(item);
        try buf.appendSlice(res.allocator, item);
    }
    try buf.appendSlice(res.allocator, "]");

    try res.ok(buf.items);
}

/// POST /community-requests
pub fn handleCreateCommunityRequest(service: *const CommunityService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isLeaderOrAdmin(req.user.?)) {
        return try res.forbidden("Only Community Leaders or Admins can submit community requests.");
    }

    const parsed = std.json.parseFromSlice(struct {
        community_name: []const u8,
        contact_person: []const u8,
        contact_phone: []const u8,
        issue: []const u8,
        urgency: []const u8,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid community request JSON payload.");
    };
    defer parsed.deinit();

    if (!Validation.isValidString(parsed.value.community_name, 1, 100)) {
        return try res.badRequest("Invalid community name. Must be 1 to 100 characters.");
    }
    if (!Validation.isValidString(parsed.value.contact_person, 1, 100)) {
        return try res.badRequest("Invalid contact person name. Must be 1 to 100 characters.");
    }
    if (!Validation.isValidPhone(parsed.value.contact_phone)) {
        return try res.badRequest("Invalid contact phone format. Must be 5 to 30 characters.");
    }
    if (!Validation.isValidString(parsed.value.issue, 3, 1000)) {
        return try res.badRequest("Invalid issue description. Must be 3 to 1000 characters.");
    }
    if (!Validation.isValidUrgency(parsed.value.urgency)) {
        return try res.badRequest("Invalid urgency classification. Valid values: low, medium, high, critical.");
    }

    const result = try service.submitRequest(
        res.allocator,
        parsed.value.community_name,
        parsed.value.contact_person,
        parsed.value.contact_phone,
        parsed.value.issue,
        parsed.value.urgency,
    );

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"Community assistance request logged successfully.\",\"request_id\":\"{s}\",\"status\":\"{s}\"}}",
        .{ result.request_id, result.status }
    );
    defer res.allocator.free(json);

    try res.created(json);
}
