const std = @import("std");
const DataStore = @import("../db/store.zig").DataStore;
const CommunityRequest = @import("../models/allocation.zig").CommunityRequest;
const jwt = @import("../auth/jwt.zig");
const http_util = @import("../utils/http_util.zig");

/// Handles `GET /allocation-metrics` - Provides regional water stress indicators and Gini fairness coefficient.
pub fn handleGetAllocationMetrics(allocator: std.mem.Allocator, response: *const http_util.Response) !void {
    const res_json = "{\"region\":\"Kunene\",\"total_population\":86856,\"working_boreholes\":142,\"broken_boreholes\":31,\"average_distance_to_water_km\":4.8,\"water_stress_index\":\"high\",\"fairness_gini_coefficient\":0.38}";
    _ = allocator;
    try http_util.sendOk(response, res_json);
}

/// Handles `GET /community-requests` - Lists active community emergency water assistance requests.
pub fn handleGetCommunityRequests(allocator: std.mem.Allocator, store: *DataStore, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .community_leader) {
        return try http_util.sendForbidden(response, "Access to community emergency water requests is restricted to Community Leaders and Administrators.");
    }

    store.mutex.lock();
    defer store.mutex.unlock();

    var list = std.ArrayList(u8).empty;
    defer list.deinit(allocator);

    try list.appendSlice(allocator, "[");
    for (store.community_requests.items, 0..) |req, i| {
        if (i > 0) try list.appendSlice(allocator, ",");
        const item_str = try std.fmt.allocPrint(allocator,
            "{{\"id\":\"{s}\",\"community_name\":\"{s}\",\"contact_person\":\"{s}\",\"contact_phone\":\"{s}\",\"issue\":\"{s}\",\"urgency\":\"{s}\",\"status\":\"{s}\",\"submitted_at\":\"{s}\"}}",
            .{
                req.id, req.community_name, req.contact_person, req.contact_phone, req.issue, req.urgency, req.status, req.submitted_at
            }
        );
        defer allocator.free(item_str);
        try list.appendSlice(allocator, item_str);
    }
    try list.appendSlice(allocator, "]");

    try http_util.sendOk(response, list.items);
}

/// Handles `POST /community-requests` - Submits an emergency water assistance request on behalf of a rural community.
pub fn handleCreateCommunityRequest(allocator: std.mem.Allocator, store: *DataStore, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .community_leader) {
        return try http_util.sendForbidden(response, "Only Community Leaders or Administrators can submit community water assistance requests.");
    }

    const parsed = std.json.parseFromSlice(struct {
        community_name: []const u8,
        contact_person: []const u8,
        contact_phone: []const u8,
        issue: []const u8,
        urgency: []const u8,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON community request payload");
    };
    defer parsed.deinit();

    const new_id = try std.fmt.allocPrint(store.allocator, "COM-REQ-{0d:0>3}", .{store.community_requests.items.len + 101});

    const req: CommunityRequest = .{
        .id = new_id,
        .community_name = try store.allocator.dupe(u8, parsed.value.community_name),
        .contact_person = try store.allocator.dupe(u8, parsed.value.contact_person),
        .contact_phone = try store.allocator.dupe(u8, parsed.value.contact_phone),
        .issue = try store.allocator.dupe(u8, parsed.value.issue),
        .urgency = try store.allocator.dupe(u8, parsed.value.urgency),
        .status = "under_review",
        .submitted_at = "2026-08-19T12:00:00Z",
    };

    store.mutex.lock();
    try store.community_requests.append(store.allocator, req);
    store.mutex.unlock();

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"Community assistance request logged successfully.\",\"request_id\":\"{s}\",\"status\":\"under_review\"}}",
        .{new_id}
    );
    defer allocator.free(res_json);

    try http_util.sendCreated(response, res_json);
}
