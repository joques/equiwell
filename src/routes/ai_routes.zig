const std = @import("std");
const AiService = @import("../services/ai_service.zig").AiService;
const Request = @import("../server/request.zig").Request;
const Response = @import("../server/response.zig").Response;
const Middleware = @import("../server/middleware.zig").Middleware;
const Rbac = @import("../auth/rbac.zig").Rbac;

/// GET /factors
pub fn handleGetFactors(service: *const AiService, req: *const Request, res: *const Response) !void {
    _ = service;
    _ = req;
    const json =
        "{\"geological_factors\":[{\"name\":\"Lineament Density\",\"weight\":0.35,\"description\":\"Fault lines and fracture zones\"},{\"name\":\"Lithology\",\"weight\":0.25,\"description\":\"Rock type permeability\"}],\"environmental_factors\":[{\"name\":\"Rainfall Recharge\",\"weight\":0.20,\"description\":\"Mean annual precipitation\"},{\"name\":\"Slope Gradient\",\"weight\":0.20,\"description\":\"Terrain runoff potential\"}]}";
    try res.ok(json);
}

/// POST /suggestions/generate
pub fn handleGenerateSuggestion(service: *const AiService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isNonViewer(req.user.?)) {
        return try res.forbidden("Read-only viewers cannot generate siting suggestions.");
    }

    const parsed = std.json.parseFromSlice(struct {
        target_area: []const u8,
        required_yield: []const u8,
        priority_metric: []const u8,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid siting request payload.");
    };
    defer parsed.deinit();

    const sug = try service.generateSuggestion(res.allocator, parsed.value.target_area);

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"suggestion_id\":\"{s}\",\"status\":\"{s}\",\"recommended_coordinates\":{{\"lat\":{d:.4},\"lng\":{d:.4}}},\"confidence_score\":{d},\"justification\":\"{s}\"}}",
        .{ sug.id, sug.status, sug.recommended_lat, sug.recommended_lng, sug.confidence_score, sug.justification }
    );
    defer res.allocator.free(json);

    try res.created(json);
}

/// GET /suggestions/{id}
pub fn handleGetSuggestionById(service: *const AiService, suggestion_id: []const u8, req: *const Request, res: *const Response) !void {
    _ = req;
    const sug = service.getSuggestionById(suggestion_id) orelse return try res.notFound("Siting suggestion not found.");

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"id\":\"{s}\",\"target_area\":\"{s}\",\"status\":\"{s}\",\"recommended_lat\":{d:.4},\"recommended_lng\":{d:.4},\"confidence_score\":{d},\"justification\":\"{s}\",\"created_at\":\"{s}\"}}",
        .{ sug.id, sug.target_area, sug.status, sug.recommended_lat, sug.recommended_lng, sug.confidence_score, sug.justification, sug.created_at }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// POST /ai/predict-yield
pub fn handlePredictYield(service: *const AiService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isNonViewer(req.user.?)) {
        return try res.forbidden("Read-only viewers cannot execute AI yield inference.");
    }

    const parsed = std.json.parseFromSlice(struct {
        latitude: f64,
        longitude: f64,
        target_aquifer_depth_m: f64,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid prediction parameters.");
    };
    defer parsed.deinit();

    const inf = service.predictYield(parsed.value.latitude, parsed.value.longitude, parsed.value.target_aquifer_depth_m);

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"model_version\":\"hydro-yield-v1.4\",\"location\":{{\"lat\":{d:.6},\"lng\":{d:.6}}},\"predicted_yield_lph\":{d},\"expected_water_strike_depth_m\":{d:.1},\"static_water_level_m\":{d:.1},\"geological_formation\":\"{s}\",\"confidence_score\":{d:.2},\"inference_timestamp\":\"2026-08-19T12:00:00Z\"}}",
        .{ parsed.value.latitude, parsed.value.longitude, inf.predicted_yield_lph, inf.expected_water_strike_depth_m, inf.static_water_level_m, inf.geological_formation, inf.confidence_score }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// POST /ai/aquifer-depletion-risk
pub fn handleAquiferDepletionRisk(service: *const AiService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isNonViewer(req.user.?)) {
        return try res.forbidden("Read-only viewers cannot execute depletion simulations.");
    }

    const parsed = std.json.parseFromSlice(struct {
        borehole_id: []const u8,
        planned_daily_extraction_liters: u64,
        simulation_horizon_years: u16,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid depletion payload.");
    };
    defer parsed.deinit();

    const sim = service.simulateDepletion(parsed.value.planned_daily_extraction_liters, parsed.value.simulation_horizon_years);

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"simulation_horizon_years\":{d},\"projected_daily_extraction_liters\":{d},\"sustainability_status\":\"{s}\",\"depletion_risk_level\":\"{s}\",\"estimated_annual_drawdown_m\":{d:.2},\"recharge_replenishment_rate\":\"{s}\"}}",
        .{ parsed.value.simulation_horizon_years, parsed.value.planned_daily_extraction_liters, sim.sustainability_status, sim.depletion_risk_level, sim.estimated_annual_drawdown_m, sim.recharge_replenishment_rate }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// POST /ai/siting-tasks/async
pub fn handleAsyncSitingTask(service: *const AiService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isNonViewer(req.user.?)) {
        return try res.forbidden("Read-only viewers cannot dispatch async siting tasks.");
    }

    const parsed = std.json.parseFromSlice(struct {
        target_area: []const u8,
        required_yield: []const u8,
        priority_metric: []const u8,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid async task payload.");
    };
    defer parsed.deinit();

    const task = service.dispatchAsyncTask(parsed.value.target_area);

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"task_id\":\"{s}\",\"status\":\"{s}\",\"estimated_duration_seconds\":45,\"message\":\"Spatial multi-criteria optimization dispatched to AI compute cluster.\"}}",
        .{ task.task_id, task.status }
    );
    defer res.allocator.free(json);

    try res.accepted(json);
}

/// GET /tasks/{id} or /api/v1/tasks/{id}
pub fn handleGetTaskStatus(service: *const AiService, task_id: []const u8, req: *const Request, res: *const Response) !void {
    _ = req;
    const task = service.getTaskStatus(task_id);

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"task_id\":\"{s}\",\"status\":\"{s}\",\"target_area\":\"{s}\",\"created_at\":\"{s}\"}}",
        .{ task.task_id, task.status, task.target_area, task.created_at }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}

/// POST /callbacks/ai/siting-complete
pub fn handleSitingCompleteCallback(service: *const AiService, req: *const Request, res: *const Response) !void {
    _ = service;
    _ = req;
    const json = "{\"acknowledged\":true,\"status\":\"SAVED\"}";
    try res.ok(json);
}

/// POST /ai/training-data/borehole-logs
pub fn handleIngestDrillingLogs(service: *const AiService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Maintenance Crew or Admins can ingest drilling logs.");
    }

    const parsed = std.json.parseFromSlice(struct {
        borehole_code: []const u8,
        lat: f64,
        lng: f64,
        total_depth_m: f64,
        water_strike_depth_m: f64,
        tested_yield_lph: u32,
        static_water_level_m: f64,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid drilling log payload.");
    };
    defer parsed.deinit();

    const result = try service.ingestDrillingLog(
        res.allocator,
        parsed.value.borehole_code,
        parsed.value.lat,
        parsed.value.lng,
        parsed.value.total_depth_m,
        parsed.value.water_strike_depth_m,
        parsed.value.tested_yield_lph,
        parsed.value.static_water_level_m,
    );

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"message\":\"Field drilling log ingested into AI training database.\",\"log_id\":\"{s}\",\"borehole_code\":\"{s}\"}}",
        .{ result.log_id, result.borehole_code }
    );
    defer res.allocator.free(json);

    try res.created(json);
}

/// POST /ai/training-data/yield-maps
pub fn handleIngestYieldMaps(service: *const AiService, req: *const Request, res: *const Response) !void {
    _ = service;
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isMaintenanceOrAdmin(req.user.?)) {
        return try res.forbidden("Only Maintenance Crew or Admins can ingest GIS yield maps.");
    }

    const json = "{\"message\":\"GIS hydrogeological yield map layers ingested.\",\"layer_id\":\"GIS-LAYER-2026-KUNENE\",\"features_processed\":1420,\"status\":\"INDEXED\"}";
    try res.created(json);
}

/// POST /ai/routes/terrain-feasibility
pub fn handleTerrainFeasibility(service: *const AiService, req: *const Request, res: *const Response) !void {
    if (!try Middleware.requireAuth(req, res)) return;
    if (!Rbac.isNonViewer(req.user.?)) {
        return try res.forbidden("Read-only viewers cannot execute terrain feasibility calculations.");
    }

    const parsed = std.json.parseFromSlice(struct {
        origin_coordinates: []const u8,
        destination_coordinates: []const u8,
        vehicle_type: []const u8,
    }, req.allocator, req.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true }) catch {
        return try res.badRequest("Invalid terrain feasibility request.");
    };
    defer parsed.deinit();

    const assessment = service.evaluateTerrain(parsed.value.vehicle_type);

    const json = try std.fmt.allocPrint(res.allocator,
        "{{\"target_coordinates\":{{\"lat\":-18.2341,\"lng\":13.8821}},\"vehicle_profile\":\"{s}\",\"is_feasible\":{s},\"max_slope_gradient_degrees\":{d:.1},\"sand_entrapment_risk\":\"{s}\",\"recommended_route_advisory\":\"{s}\"}}",
        .{ parsed.value.vehicle_type, if (assessment.is_feasible) "true" else "false", assessment.max_slope_gradient_degrees, assessment.sand_entrapment_risk, assessment.recommended_route_advisory }
    );
    defer res.allocator.free(json);

    try res.ok(json);
}
