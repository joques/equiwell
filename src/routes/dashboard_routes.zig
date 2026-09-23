const std = @import("std");
const BoreholeService = @import("../services/borehole_service.zig").BoreholeService;
const Request = @import("../server/request.zig").Request;
const Response = @import("../server/response.zig").Response;

/// GET /dashboard/summary or /api/v1/dashboard/summary
pub fn handleSummary(service: *const BoreholeService, req: *const Request, res: *const Response) !void {
    _ = req;
    const summary = service.getDashboardSummary();

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"total_boreholes\":{d},\"working_boreholes\":{d},\"broken_boreholes\":{d},\"communities_at_risk\":{d},\"recent_installations_this_year\":{d},\"latest_borehole_implemented_date\":\"{s}\",\"last_synced_at\":\"{s}\"}}",
        .{
            summary.total_boreholes,
            summary.working_boreholes,
            summary.broken_boreholes,
            summary.communities_at_risk,
            summary.recent_installations_this_year,
            summary.latest_borehole_implemented_date,
            summary.last_synced_at,
        }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}
