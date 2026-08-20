const std = @import("std");

/// Multi-criteria AI recommendation for new borehole drilling coordinates.
pub const SitingSuggestion = struct {
    /// Unique recommendation ID (e.g. "SUG-1001").
    id: []const u8,
    /// Target geographic district or constituency (e.g. "Okangwati").
    target_area: []const u8,
    /// Expected yield requirement category ("low", "moderate", "high").
    required_yield: []const u8,
    /// Dominant prioritization metric ("fair_allocation_distance", "geological_confidence").
    priority_metric: []const u8,
    /// Processing lifecycle state ("queued", "processing", "complete", "failed").
    status: []const u8,
    /// Recommended latitude coordinate.
    recommended_lat: f64,
    /// Recommended longitude coordinate.
    recommended_lng: f64,
    /// Multi-criteria spatial confidence score (0-100%).
    confidence_score: u32,
    /// Hydrogeological and socio-demographic rationale for the recommended coordinates.
    justification: []const u8,
    /// Timestamp of recommendation generation.
    created_at: []const u8,
};

/// Ground truth drilling log collected during field borehole installation.
pub const BoreholeDrillingLog = struct {
    /// Unique field drilling log ID (e.g. "DLOG-00001").
    id: []const u8,
    /// Assigned borehole asset code.
    borehole_code: []const u8,
    /// Exact surveyed latitude.
    lat: f64,
    /// Exact surveyed longitude.
    lng: f64,
    /// Total drilled depth in meters.
    total_depth_m: f64,
    /// Depth where the main water strike occurred in meters.
    water_strike_depth_m: f64,
    /// Measured 24-hour pumping test yield in Liters per Hour (L/h).
    tested_yield_lph: u32,
    /// Rest static water table level in meters below surface.
    static_water_level_m: f64,
    /// Timestamp of field ingestion.
    ingested_at: []const u8,
};
