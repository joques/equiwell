const std = @import("std");
const HealthService = @import("../services/health_service.zig").HealthService;
const Request = @import("../server/request.zig").Request;
const Response = @import("../server/response.zig").Response;
const Middleware = @import("../server/middleware.zig").Middleware;
const Rbac = @import("../auth/rbac.zig").Rbac;
const Validation = @import("../utils/validation.zig").Validation;

/// POST /boreholes/{id}/lab-tests
pub fn handleCreateLabTest(service: *const HealthService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isHealthOrAdmin(req.user.?)) {
        return try res.forbidden("Only Health Inspectors or Admins can record laboratory tests.");
    }
    if (!Validation.isValidString(borehole_id, 1, 50)) {
        return try res.badRequest("Invalid borehole ID parameter.");
    }

    const parsed = std.json.parseFromSlice(struct {
        test_date: []const u8,
        e_coli_detected: bool,
        arsenic_mg_l: f64,
        fluoride_mg_l: f64,
        is_safe_for_consumption: bool,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid lab test JSON payload.");
    };
    defer parsed.deinit();

    if (!Validation.isValidDate(parsed.value.test_date)) {
        return try res.badRequest("Invalid test_date format. Must be YYYY-MM-DD.");
    }
    if (!Validation.isValidPositiveFloat(parsed.value.arsenic_mg_l, 1000.0)) {
        return try res.badRequest("Invalid arsenic concentration. Must be a non-negative finite number <= 1000 mg/L.");
    }
    if (!Validation.isValidPositiveFloat(parsed.value.fluoride_mg_l, 1000.0)) {
        return try res.badRequest("Invalid fluoride concentration. Must be a non-negative finite number <= 1000 mg/L.");
    }

    const inspector_id = req.user.?.sub;
    const result = service.recordLabTest(
        res.allocator,
        borehole_id,
        inspector_id,
        parsed.value.test_date,
        parsed.value.e_coli_detected,
        parsed.value.arsenic_mg_l,
        parsed.value.fluoride_mg_l,
        parsed.value.is_safe_for_consumption,
    ) catch |err| {
        if (err == error.NotFound) {
            return try res.notFound("Borehole not found.");
        }
        return try res.internalError("Failed to record lab test.");
    };

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"Water quality certificate recorded successfully.\",\"test_id\":\"{s}\",\"borehole_id\":\"{s}\"}}",
        .{ result.test_id, result.borehole_id }
    );
    defer res.allocator.free(json);

    try res.created(json);
}

/// GET /boreholes/{id}/lab-tests
pub fn handleGetLabTests(service: *const HealthService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isHealthOrAdmin(req.user.?)) {
        return try res.forbidden("Only Health Inspectors or Admins can view laboratory test histories.");
    }
    if (!Validation.isValidString(borehole_id, 1, 50)) {
        return try res.badRequest("Invalid borehole ID parameter.");
    }

    const tests = service.getLabTests(res.allocator, borehole_id) catch |err| {
        if (err == error.NotFound) return try res.notFound("Borehole not found.");
        return try res.internalError("Failed to retrieve lab tests.");
    };
    defer res.allocator.free(tests);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(res.allocator);
    try buf.appendSlice(res.allocator, "[");
    for (tests, 0..) |t, i| {
        if (i > 0) try buf.appendSlice(res.allocator, ",");
        const item = try std.fmt.allocPrint(res.allocator,
            "{{\"id\":\"{s}\",\"borehole_id\":\"{s}\",\"inspector_id\":\"{s}\",\"test_date\":\"{s}\",\"e_coli_detected\":{s},\"arsenic_mg_l\":{d:.4},\"fluoride_mg_l\":{d:.2},\"is_safe_for_consumption\":{s}}}",
            .{
                t.id,
                t.borehole_id,
                t.inspector_id,
                t.test_date,
                if (t.e_coli_detected) "true" else "false",
                t.arsenic_mg_l,
                t.fluoride_mg_l,
                if (t.is_safe_for_consumption) "true" else "false",
            }
        );
        defer res.allocator.free(item);
        try buf.appendSlice(res.allocator, item);
    }
    try buf.appendSlice(res.allocator, "]");

    try res.ok(buf.items);
}

/// GET /boreholes/{id}/usage-quotas
pub fn handleGetUsageQuota(service: *const HealthService, borehole_id: []const u8, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isHealthOrAdmin(req.user.?)) {
        return try res.forbidden("Only Health Inspectors or Admins can view usage quotas.");
    }
    if (!Validation.isValidString(borehole_id, 1, 50)) {
        return try res.badRequest("Invalid borehole ID parameter.");
    }

    const quota = service.getUsageQuota(borehole_id) catch |err| {
        if (err == error.NotFound) return try res.notFound("Borehole not found.");
        return try res.internalError("Failed to retrieve usage quota.");
    };

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"borehole_id\":\"{s}\",\"monthly_quota_liters\":{d},\"current_usage_liters\":{d},\"status\":\"{s}\",\"billing_period\":\"{s}\"}}",
        .{ quota.borehole_id, quota.monthly_quota_liters, quota.current_usage_liters, quota.status, quota.billing_period }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}
