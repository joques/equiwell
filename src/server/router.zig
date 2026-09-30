const std = @import("std");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const UserService = @import("../services/user_service.zig").UserService;
const BoreholeService = @import("../services/borehole_service.zig").BoreholeService;
const HealthService = @import("../services/health_service.zig").HealthService;
const TelemetryService = @import("../services/telemetry_service.zig").TelemetryService;
const MaintenanceService = @import("../services/maintenance_service.zig").MaintenanceService;
const AllocationService = @import("../services/allocation_service.zig").AllocationService;
const CommunityService = @import("../services/community_service.zig").CommunityService;
const LogisticsService = @import("../services/logistics_service.zig").LogisticsService;
const AiService = @import("../services/ai_service.zig").AiService;
const Metrics = @import("../observability/metrics.zig").Metrics;

// Route Handlers
const dashboard_routes = @import("../routes/dashboard_routes.zig");
const user_routes = @import("../routes/user_routes.zig");
const borehole_routes = @import("../routes/borehole_routes.zig");
const health_routes = @import("../routes/health_routes.zig");
const maintenance_routes = @import("../routes/maintenance_routes.zig");
const allocation_routes = @import("../routes/allocation_routes.zig");
const logistics_routes = @import("../routes/logistics_routes.zig");
const ai_routes = @import("../routes/ai_routes.zig");

/// Centralized HTTP Request Router dispatching to domain controllers.
pub const Router = struct {
    user_service: *UserService,
    borehole_service: *BoreholeService,
    health_service: *HealthService,
    telemetry_service: *TelemetryService,
    maintenance_service: *MaintenanceService,
    allocation_service: *AllocationService,
    community_service: *CommunityService,
    logistics_service: *LogisticsService,
    ai_service: *AiService,
    metrics: *Metrics,

    pub fn init(
        user_service: *UserService,
        borehole_service: *BoreholeService,
        health_service: *HealthService,
        telemetry_service: *TelemetryService,
        maintenance_service: *MaintenanceService,
        allocation_service: *AllocationService,
        community_service: *CommunityService,
        logistics_service: *LogisticsService,
        ai_service: *AiService,
        metrics: *Metrics,
    ) Router {
        return .{
            .user_service = user_service,
            .borehole_service = borehole_service,
            .health_service = health_service,
            .telemetry_service = telemetry_service,
            .maintenance_service = maintenance_service,
            .allocation_service = allocation_service,
            .community_service = community_service,
            .logistics_service = logistics_service,
            .ai_service = ai_service,
            .metrics = metrics,
        };
    }

    /// Normalizes path by stripping `/api/v1` prefix if present for uniform routing.
    pub fn normalizePath(raw_path: []const u8) []const u8 {
        if (std.mem.startsWith(u8, raw_path, "/api/v1/")) {
            return raw_path[7..]; // e.g. "/api/v1/boreholes" -> "/boreholes"
        } else if (std.mem.eql(u8, raw_path, "/api/v1")) {
            return "/";
        }
        return raw_path;
    }

    /// Dispatches an incoming HTTP request to the appropriate route controller.
    pub fn dispatch(self: *const Router, req: *const Request, res: *const Response) !void {
        const path = normalizePath(req.path);
        const method = req.method;

        // ----------------------------------------------------
        // 0. HEALTH PROBE & METRICS ENDPOINTS
        // ----------------------------------------------------
        if (std.mem.eql(u8, method, "GET") and (std.mem.eql(u8, path, "/health") or std.mem.eql(u8, path, "/health/live"))) {
            return try res.ok("{\"status\":\"UP\",\"checks\":{\"service\":\"equiwell-api\",\"uptime\":\"OK\"}}");
        }
        if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/health/ready")) {
            return try res.ok("{\"status\":\"READY\",\"database\":\"connected\",\"version\":\"1.0.0\"}");
        }
        if (std.mem.eql(u8, method, "GET") and (std.mem.eql(u8, path, "/metrics") or std.mem.eql(u8, req.path, "/metrics") or std.mem.eql(u8, req.path, "/api/v1/metrics"))) {
            const json = try self.metrics.formatJson(res.allocator);
            defer res.allocator.free(json);
            return try res.ok(json);
        }

        // ----------------------------------------------------
        // 1. DASHBOARD MODULE
        // ----------------------------------------------------
        if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/dashboard/summary")) {
            return try dashboard_routes.handleSummary(self.borehole_service, req, res);
        }

        // ----------------------------------------------------
        // 2. USERS & AUTHENTICATION MODULE
        // ----------------------------------------------------
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/users/register")) {
            return try user_routes.handleRegister(self.user_service, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/users/login")) {
            return try user_routes.handleLogin(self.user_service, req, res);
        }
        if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/users")) {
            return try user_routes.handleListUsers(self.user_service, req, res);
        }
        if (std.mem.startsWith(u8, path, "/users/")) {
            const sub = path[7..];

            if (std.mem.endsWith(u8, sub, "/role") and std.mem.eql(u8, method, "PATCH")) {
                const user_id = sub[0 .. sub.len - 5];
                return try user_routes.handleUpdateUserRole(self.user_service, user_id, req, res);
            }

            const user_id = sub;
            if (std.mem.eql(u8, method, "GET")) {
                return try user_routes.handleGetUserById(self.user_service, user_id, req, res);
            }
            if (std.mem.eql(u8, method, "PUT")) {
                return try user_routes.handleUpdateUser(self.user_service, user_id, req, res);
            }
            if (std.mem.eql(u8, method, "DELETE")) {
                return try user_routes.handleDeleteUser(self.user_service, user_id, req, res);
            }
        }

        // ----------------------------------------------------
        // 3. BOREHOLES & SUB-RESOURCES MODULE
        // ----------------------------------------------------
        if (std.mem.eql(u8, path, "/boreholes")) {
            if (std.mem.eql(u8, method, "GET")) {
                return try borehole_routes.handleGetBoreholes(self.borehole_service, req, res);
            }
            if (std.mem.eql(u8, method, "POST")) {
                return try borehole_routes.handleCreateBorehole(self.borehole_service, req, res);
            }
        }

        if (std.mem.startsWith(u8, path, "/boreholes/")) {
            const rest = path[11..];

            // Sub-resource: /boreholes/{id}/lab-tests
            if (std.mem.endsWith(u8, rest, "/lab-tests")) {
                const bh_id = rest[0 .. rest.len - 10];
                if (std.mem.eql(u8, method, "POST")) {
                    return try health_routes.handleCreateLabTest(self.health_service, bh_id, req, res);
                }
                if (std.mem.eql(u8, method, "GET")) {
                    return try health_routes.handleGetLabTests(self.health_service, bh_id, req, res);
                }
            }

            // Sub-resource: /boreholes/{id}/usage-quotas
            if (std.mem.endsWith(u8, rest, "/usage-quotas") and std.mem.eql(u8, method, "GET")) {
                const bh_id = rest[0 .. rest.len - 13];
                return try health_routes.handleGetUsageQuota(self.health_service, bh_id, req, res);
            }

            // Sub-resource: /boreholes/{id}/telemetry
            if (std.mem.endsWith(u8, rest, "/telemetry") and std.mem.eql(u8, method, "POST")) {
                const bh_id = rest[0 .. rest.len - 10];
                return try maintenance_routes.handleIngestTelemetry(self.telemetry_service, bh_id, req, res);
            }

            // Sub-resource: /boreholes/{id}/history
            if (std.mem.endsWith(u8, rest, "/history") and std.mem.eql(u8, method, "GET")) {
                const bh_id = rest[0 .. rest.len - 8];
                return try maintenance_routes.handleGetYieldHistory(self.maintenance_service, bh_id, req, res);
            }

            // Sub-resource: /boreholes/{id}/logistics
            if (std.mem.endsWith(u8, rest, "/logistics") and std.mem.eql(u8, method, "GET")) {
                const bh_id = rest[0 .. rest.len - 10];
                return try logistics_routes.handleGetBoreholeLogistics(self.logistics_service, bh_id, req, res);
            }

            // Core Borehole Single Asset CRUD: /boreholes/{id}
            const bh_id = rest;
            if (std.mem.eql(u8, method, "GET")) {
                return try borehole_routes.handleGetBoreholeById(self.borehole_service, bh_id, req, res);
            }
            if (std.mem.eql(u8, method, "PUT")) {
                return try borehole_routes.handleUpdateBorehole(self.borehole_service, bh_id, req, res);
            }
            if (std.mem.eql(u8, method, "PATCH")) {
                return try borehole_routes.handlePatchBorehole(self.borehole_service, bh_id, req, res);
            }
            if (std.mem.eql(u8, method, "DELETE")) {
                return try borehole_routes.handleDeleteBorehole(self.borehole_service, bh_id, req, res);
            }
        }

        // ----------------------------------------------------
        // 4. MAINTENANCE & ALERTS MODULE
        // ----------------------------------------------------
        if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/maintenance-alerts")) {
            return try maintenance_routes.handleGetMaintenanceAlerts(self.maintenance_service, req, res);
        }

        // ----------------------------------------------------
        // 5. ALLOCATION & COMMUNITY REQUESTS MODULE
        // ----------------------------------------------------
        if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/allocation-metrics")) {
            return try allocation_routes.handleGetAllocationMetrics(self.allocation_service, req, res);
        }
        if (std.mem.eql(u8, path, "/community-requests")) {
            if (std.mem.eql(u8, method, "GET")) {
                return try allocation_routes.handleGetCommunityRequests(self.community_service, req, res);
            }
            if (std.mem.eql(u8, method, "POST")) {
                return try allocation_routes.handleCreateCommunityRequest(self.community_service, req, res);
            }
        }

        // ----------------------------------------------------
        // 6. LOGISTICS & ROUTING MODULE
        // ----------------------------------------------------
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/routes/calculate")) {
            return try logistics_routes.handleCalculateRoute(self.logistics_service, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/routes/google-maps-directions")) {
            return try logistics_routes.handleGoogleMapsDirections(self.logistics_service, req, res);
        }

        // ----------------------------------------------------
        // 7. AI SITING & HYDROGEOLOGY MODULE
        // ----------------------------------------------------
        if (std.mem.eql(u8, method, "GET") and std.mem.eql(u8, path, "/factors")) {
            return try ai_routes.handleGetFactors(self.ai_service, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/suggestions/generate")) {
            return try ai_routes.handleGenerateSuggestion(self.ai_service, req, res);
        }
        if (std.mem.startsWith(u8, path, "/suggestions/") and std.mem.eql(u8, method, "GET")) {
            const sug_id = path[13..];
            return try ai_routes.handleGetSuggestionById(self.ai_service, sug_id, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/predict-yield")) {
            return try ai_routes.handlePredictYield(self.ai_service, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/aquifer-depletion-risk")) {
            return try ai_routes.handleAquiferDepletionRisk(self.ai_service, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/siting-tasks/async")) {
            return try ai_routes.handleAsyncSitingTask(self.ai_service, req, res);
        }
        if (std.mem.startsWith(u8, path, "/tasks/") and std.mem.eql(u8, method, "GET")) {
            const task_id = path[7..];
            return try ai_routes.handleGetTaskStatus(self.ai_service, task_id, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/callbacks/ai/siting-complete")) {
            return try ai_routes.handleSitingCompleteCallback(self.ai_service, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/training-data/borehole-logs")) {
            return try ai_routes.handleIngestDrillingLogs(self.ai_service, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/training-data/yield-maps")) {
            return try ai_routes.handleIngestYieldMaps(self.ai_service, req, res);
        }
        if (std.mem.eql(u8, method, "POST") and std.mem.eql(u8, path, "/ai/routes/terrain-feasibility")) {
            return try ai_routes.handleTerrainFeasibility(self.ai_service, req, res);
        }

        // ----------------------------------------------------
        // 8. NOT FOUND FALLBACK
        // ----------------------------------------------------
        try res.notFound("The requested endpoint route does not exist on this server.");
    }
};
