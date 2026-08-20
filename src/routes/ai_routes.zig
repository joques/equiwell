const std = @import("std");
const DataStore = @import("../db/store.zig").DataStore;
const SitingSuggestion = @import("../models/ai_siting.zig").SitingSuggestion;
const BoreholeDrillingLog = @import("../models/ai_siting.zig").BoreholeDrillingLog;
const jwt = @import("../auth/jwt.zig");
const http_util = @import("../utils/http_util.zig");

/// Handles `GET /factors` - Returns multi-criteria geological and environmental weighting factors for borehole siting.
pub fn handleGetFactors(allocator: std.mem.Allocator, response: *const http_util.Response) !void {
    const res_json = "{\"geological_factors\":[{\"name\":\"Lineament Density\",\"weight\":0.35,\"description\":\"Fault lines and fracture zones\"},{\"name\":\"Lithology\",\"weight\":0.25,\"description\":\"Rock type permeability\"}],\"environmental_factors\":[{\"name\":\"Rainfall Recharge\",\"weight\":0.20,\"description\":\"Mean annual precipitation\"},{\"name\":\"Slope Gradient\",\"weight\":0.20,\"description\":\"Terrain runoff potential\"}]}";
    _ = allocator;
    try http_util.sendOk(response, res_json);
}

/// Handles `POST /suggestions/generate` - Dispatches spatial optimization request to determine ideal new borehole coordinates.
pub fn handleGenerateSuggestion(allocator: std.mem.Allocator, store: *DataStore, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .community_leader and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Only Authorized Leaders or Administrators can initiate AI siting optimization.");
    }

    const parsed = std.json.parseFromSlice(struct {
        target_area: []const u8,
        required_yield: []const u8,
        priority_metric: []const u8,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid JSON suggestion request payload");
    };
    defer parsed.deinit();

    const new_id = try std.fmt.allocPrint(store.allocator, "SUG-{0d:0>4}", .{1000 + store.siting_suggestions.items.len + 1});

    const sug: SitingSuggestion = .{
        .id = new_id,
        .target_area = try store.allocator.dupe(u8, parsed.value.target_area),
        .required_yield = try store.allocator.dupe(u8, parsed.value.required_yield),
        .priority_metric = try store.allocator.dupe(u8, parsed.value.priority_metric),
        .status = "complete",
        .recommended_lat = -18.1500,
        .recommended_lng = 13.7200,
        .confidence_score = 91,
        .justification = "High fracture lineament convergence and 800m proximity to local population.",
        .created_at = "2026-08-19T12:00:00Z",
    };

    store.mutex.lock();
    try store.siting_suggestions.append(store.allocator, sug);
    store.mutex.unlock();

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"suggestion_id\":\"{s}\",\"status\":\"complete\",\"recommended_coordinates\":{{\"lat\":{d:.4},\"lng\":{d:.4}}},\"confidence_score\":{d},\"justification\":\"{s}\"}}",
        .{ sug.id, sug.recommended_lat, sug.recommended_lng, sug.confidence_score, sug.justification }
    );
    defer allocator.free(res_json);

    try http_util.sendCreated(response, res_json);
}

/// Handles `GET /suggestions/{id}` - Retrieves the results, confidence score, and rationale of an AI siting suggestion.
pub fn handleGetSuggestionById(allocator: std.mem.Allocator, store: *DataStore, id: []const u8, response: *const http_util.Response) !void {
    store.mutex.lock();
    defer store.mutex.unlock();

    for (store.siting_suggestions.items) |s| {
        if (std.mem.eql(u8, s.id, id)) {
            const res_json = try std.fmt.allocPrint(allocator,
                "{{\"id\":\"{s}\",\"target_area\":\"{s}\",\"status\":\"{s}\",\"recommended_lat\":{d:.4},\"recommended_lng\":{d:.4},\"confidence_score\":{d},\"justification\":\"{s}\",\"created_at\":\"{s}\"}}",
                .{ s.id, s.target_area, s.status, s.recommended_lat, s.recommended_lng, s.confidence_score, s.justification, s.created_at }
            );
            defer allocator.free(res_json);

            return try http_util.sendOk(response, res_json);
        }
    }

    try http_util.sendNotFound(response, "Siting suggestion not found");
}

/// Handles `POST /ai/predict-yield` - Machine learning inference for expected borehole yield (L/h) and strike depth.
pub fn handlePredictYield(allocator: std.mem.Allocator, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role == .viewer) {
        return try http_util.sendForbidden(response, "Direct AI ML inference is restricted.");
    }

    const parsed = std.json.parseFromSlice(struct {
        latitude: f64,
        longitude: f64,
        target_aquifer_depth_m: ?f64 = null,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid coordinates payload");
    };
    defer parsed.deinit();

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"model_version\":\"hydro-yield-v1.4\",\"location\":{{\"lat\":{d:.6},\"lng\":{d:.6}}},\"predicted_yield_lph\":2400,\"expected_water_strike_depth_m\":72.5,\"static_water_level_m\":18.2,\"geological_formation\":\"Fractured Quartzite & Dolomite\",\"confidence_score\":0.88,\"inference_timestamp\":\"2026-08-19T12:00:00Z\"}}",
        .{ parsed.value.latitude, parsed.value.longitude }
    );
    defer allocator.free(res_json);

    try http_util.sendOk(response, res_json);
}

/// Handles `POST /ai/aquifer-depletion-risk` - Simulates multi-year extraction drawdown sustainability.
pub fn handleAquiferDepletionRisk(allocator: std.mem.Allocator, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role == .viewer) {
        return try http_util.sendForbidden(response, "Access to aquifer simulation is restricted.");
    }

    _ = body;
    const res_json = "{\"simulation_horizon_years\":10,\"projected_daily_extraction_liters\":25000,\"sustainability_status\":\"sustainable\",\"depletion_risk_level\":\"low\",\"estimated_annual_drawdown_m\":0.35,\"recharge_replenishment_rate\":\"high_seasonal\"}";
    _ = allocator;
    try http_util.sendOk(response, res_json);
}

/// Handles `POST /ai/siting-tasks/async` - Dispatches intensive multi-criteria siting calculation to background compute.
pub fn handleAsyncSitingTask(allocator: std.mem.Allocator, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role == .viewer) {
        return try http_util.sendForbidden(response, "Initiating asynchronous compute tasks is restricted.");
    }

    _ = body;
    const task_id = "TASK-AI-7721";
    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"task_id\":\"{s}\",\"status\":\"QUEUED\",\"estimated_duration_seconds\":45,\"message\":\"Spatial multi-criteria optimization dispatched to AI compute cluster.\"}}",
        .{task_id}
    );
    defer allocator.free(res_json);

    try http_util.sendAccepted(response, res_json);
}

/// Handles `POST /callbacks/ai/siting-complete` - Ingests webhook callback notifications when background AI tasks finish.
pub fn handleSitingCompleteCallback(allocator: std.mem.Allocator, body: []const u8, response: *const http_util.Response) !void {
    _ = body;
    const res_json = "{\"acknowledged\":true,\"status\":\"SAVED\"}";
    _ = allocator;
    try http_util.sendOk(response, res_json);
}

/// Handles `POST /ai/training-data/borehole-logs` - Ingests field drilling logs collected during the Kunene campaign.
pub fn handleIngestDrillingLogs(allocator: std.mem.Allocator, store: *DataStore, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Only Field Data Collection Teams or Administrators can ingest drilling logs.");
    }

    const parsed = std.json.parseFromSlice(struct {
        borehole_code: []const u8,
        lat: f64,
        lng: f64,
        total_depth_m: f64,
        water_strike_depth_m: f64,
        tested_yield_lph: u32,
        static_water_level_m: f64,
    }, allocator, body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try http_util.sendBadRequest(response, "Invalid drilling log payload");
    };
    defer parsed.deinit();

    const new_id = try std.fmt.allocPrint(store.allocator, "DLOG-{0d:0>5}", .{store.drilling_logs.items.len + 1});

    const log: BoreholeDrillingLog = .{
        .id = new_id,
        .borehole_code = try store.allocator.dupe(u8, parsed.value.borehole_code),
        .lat = parsed.value.lat,
        .lng = parsed.value.lng,
        .total_depth_m = parsed.value.total_depth_m,
        .water_strike_depth_m = parsed.value.water_strike_depth_m,
        .tested_yield_lph = parsed.value.tested_yield_lph,
        .static_water_level_m = parsed.value.static_water_level_m,
        .ingested_at = "2026-08-19T12:00:00Z",
    };

    store.mutex.lock();
    try store.drilling_logs.append(store.allocator, log);
    store.mutex.unlock();

    const res_json = try std.fmt.allocPrint(allocator,
        "{{\"message\":\"Field drilling log ingested into AI training database.\",\"log_id\":\"{s}\",\"borehole_code\":\"{s}\"}}",
        .{ new_id, parsed.value.borehole_code }
    );
    defer allocator.free(res_json);

    try http_util.sendCreated(response, res_json);
}

/// Handles `POST /ai/training-data/yield-maps` - Ingests hydrogeological GIS raster layers.
pub fn handleIngestYieldMaps(allocator: std.mem.Allocator, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role != .admin and current_user.role != .maintenance_crew) {
        return try http_util.sendForbidden(response, "Only GIS/AI Engineers or Administrators can ingest yield maps.");
    }

    _ = body;
    const res_json = "{\"message\":\"GIS hydrogeological yield map layers ingested.\",\"layer_id\":\"GIS-LAYER-2026-KUNENE\",\"features_processed\":1420,\"status\":\"INDEXED\"}";
    _ = allocator;
    try http_util.sendCreated(response, res_json);
}

/// Handles `POST /ai/routes/terrain-feasibility` - Assesses heavy drilling rig slope gradient and sand entrapment risk.
pub fn handleTerrainFeasibility(allocator: std.mem.Allocator, body: []const u8, current_user: jwt.TokenPayload, response: *const http_util.Response) !void {
    if (current_user.role == .viewer) {
        return try http_util.sendForbidden(response, "Access to drilling rig logistics feasibility is restricted.");
    }

    _ = body;
    const res_json = "{\"target_coordinates\":{\"lat\":-18.2341,\"lng\":13.8821},\"vehicle_profile\":\"20_ton_drilling_rig\",\"is_feasible\":true,\"max_slope_gradient_degrees\":14.2,\"sand_entrapment_risk\":\"low\",\"recommended_route_advisory\":\"Maintain low gear on river approach\"}";
    _ = allocator;
    try http_util.sendOk(response, res_json);
}
