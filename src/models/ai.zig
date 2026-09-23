const std = @import("std");

/// Spatial AI siting recommendation.
pub const SitingSuggestion = struct {
    id: []const u8,
    target_area: []const u8,
    status: []const u8,
    recommended_lat: f64,
    recommended_lng: f64,
    confidence_score: u8,
    justification: []const u8,
    created_at: []const u8,
};

/// Ground-truth geological drilling log collected during field campaigns.
pub const BoreholeDrillingLog = struct {
    id: []const u8,
    borehole_code: []const u8,
    lat: f64,
    lng: f64,
    total_depth_m: f64,
    water_strike_depth_m: f64,
    tested_yield_lph: u32,
    static_water_level_m: f64,
    created_at: []const u8,
};

/// Asynchronous AI computation task status.
pub const AsyncTaskStatus = struct {
    task_id: []const u8,
    status: []const u8,
    target_area: []const u8,
    created_at: []const u8,
    completed_at: ?[]const u8 = null,
};
