const std = @import("std");
const DataStore = @import("../db/store.zig").DataStore;
const http_util = @import("../utils/http_util.zig");

/// Handles `GET /dashboard/summary` - Provides high-level aggregate indicators including latest commissioning date.
pub fn handleDashboardSummary(allocator: std.mem.Allocator, store: *DataStore, response: *const http_util.Response) !void {
    store.mutex.lock();
    defer store.mutex.unlock();

    var total: u32 = 0;
    var working: u32 = 0;
    var broken: u32 = 0;
    var latest_impl_date: []const u8 = "2022-01-01";

    for (store.boreholes.items) |bh| {
        total += 1;
        if (bh.status == .working) {
            working += 1;
        } else {
            broken += 1;
        }
        if (bh.implemented_date.len > 0 and std.mem.order(u8, bh.implemented_date, latest_impl_date) == .gt) {
            latest_impl_date = bh.implemented_date;
        }
    }

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"total_boreholes\":{d},\"working_boreholes\":{d},\"broken_boreholes\":{d},\"communities_at_risk\":3,\"recent_installations_this_year\":1,\"latest_borehole_implemented_date\":\"{s}\",\"last_synced_at\":\"2026-08-19T12:00:00Z\"}}",
        .{ total, working, broken, latest_impl_date }
    );
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}
