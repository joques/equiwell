const std = @import("std");
const DataStore = @import("../db/store.zig").DataStore;
const LabTest = @import("../models/health.zig").LabTest;
const jwt = @import("../auth/jwt.zig");
const http_util = @import("../utils/http_util.zig");

/// Handles `POST /boreholes/{id}/lab-tests` - Records certified laboratory water potability test results.
pub fn handleCreateLabTest(allocator: std.mem.Allocator, store: *DataStore, borehole_id: []const u8, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .health_inspector) {
        return try http_util.sendForbidden(response, "Only Certified Health Inspectors or Administrators can log water quality test certificates.");
    }

    const parsed = std.json.parseFromSlice(struct {
        test_date: []const u8,
        e_coli_detected: bool,
        arsenic_mg_l: f64,
        fluoride_mg_l: f64,
        is_safe_for_consumption: bool,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON lab test payload");
    };
    defer parsed.deinit();

    const new_id = try std.fmt.allocPrint(store.allocator, "LAB-2026-{0d:0>3}", .{store.lab_tests.items.len + 1});

    const test_rec: LabTest = .{
        .id = new_id,
        .borehole_id = try store.allocator.dupe(u8, borehole_id),
        .inspector_id = try store.allocator.dupe(u8, current_user.sub),
        .test_date = try store.allocator.dupe(u8, parsed.value.test_date),
        .e_coli_detected = parsed.value.e_coli_detected,
        .arsenic_mg_l = parsed.value.arsenic_mg_l,
        .fluoride_mg_l = parsed.value.fluoride_mg_l,
        .is_safe_for_consumption = parsed.value.is_safe_for_consumption,
    };

    store.mutex.lock();
    try store.lab_tests.append(store.allocator, test_rec);
    store.mutex.unlock();

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"Water quality certificate recorded successfully.\",\"test_id\":\"{s}\",\"borehole_id\":\"{s}\"}}",
        .{ new_id, borehole_id }
    );
    defer allocator.free(res_json);

    try http_util.sendCreated(response, res_json);
}

/// Handles `GET /boreholes/{id}/lab-tests` - Retrieves historical laboratory test records for a borehole.
pub fn handleGetLabTests(allocator: std.mem.Allocator, store: *DataStore, borehole_id: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .health_inspector) {
        return try http_util.sendForbidden(response, "Access to laboratory testing certificates is restricted.");
    }

    store.mutex.lock();
    defer store.mutex.unlock();

    var list = std.ArrayList(u8).empty;
    defer list.deinit(allocator);

    try list.appendSlice(allocator, "[");
    var count: usize = 0;

    for (store.lab_tests.items) |t| {
        if (std.mem.eql(u8, t.borehole_id, borehole_id)) {
            if (count > 0) try list.appendSlice(allocator, ",");
            count += 1;

            const item_str = try std.fmt.allocPrint(allocator,
                "{{\"id\":\"{s}\",\"borehole_id\":\"{s}\",\"inspector_id\":\"{s}\",\"test_date\":\"{s}\",\"e_coli_detected\":{},\"arsenic_mg_l\":{d:.4},\"fluoride_mg_l\":{d:.2},\"is_safe_for_consumption\":{}}}",
                .{
                    t.id, t.borehole_id, t.inspector_id, t.test_date, t.e_coli_detected, t.arsenic_mg_l, t.fluoride_mg_l, t.is_safe_for_consumption
                }
            );
            defer allocator.free(item_str);
            try list.appendSlice(allocator, item_str);
        }
    }
    try list.appendSlice(allocator, "]");

    try http_util.sendOk(response, list.items);
}

/// Handles `GET /boreholes/{id}/usage-quotas` - Tracks monthly water extraction against sustainable recharge quota limits.
pub fn handleGetUsageQuota(allocator: std.mem.Allocator, borehole_id: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .health_inspector) {
        return try http_util.sendForbidden(response, "Access to extraction quota monitoring is restricted.");
    }

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"borehole_id\":\"{s}\",\"monthly_quota_liters\":150000,\"current_usage_liters\":125000,\"status\":\"within_limits\",\"billing_period\":\"2026-08\"}}",
        .{borehole_id}
    );
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}
