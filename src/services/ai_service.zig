const std = @import("std");
const Database = @import("../database/database.zig").Database;
const AiWorkerClient = @import("../integrations/ai_worker.zig").AiWorkerClient;
const SitingSuggestion = @import("../models/ai.zig").SitingSuggestion;
const BoreholeDrillingLog = @import("../models/ai.zig").BoreholeDrillingLog;
const AsyncTaskStatus = @import("../models/ai.zig").AsyncTaskStatus;
const YieldInference = @import("../domain/hydrogeology/yield_prediction.zig").YieldInference;
const DepletionSimulation = @import("../domain/hydrogeology/depletion.zig").DepletionSimulation;
const TerrainFeasibility = @import("../domain/terrain/feasibility.zig").TerrainFeasibility;
const Ids = @import("../utils/ids.zig").Ids;

pub const AiService = struct {
    db: *Database,
    worker_client: AiWorkerClient,

    pub fn init(db: *Database, worker_client: AiWorkerClient) AiService {
        return .{
            .db = db,
            .worker_client = worker_client,
        };
    }

    pub fn generateSuggestion(
        self: AiService,
        allocator: std.mem.Allocator,
        target_area: []const u8,
    ) !SitingSuggestion {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const count = self.db.siting_suggestions.items.len;
        const id = try Ids.formatSuggestionId(allocator, count + 1);

        const sug: SitingSuggestion = .{
            .id = try self.db.allocator.dupe(u8, id),
            .target_area = try self.db.allocator.dupe(u8, target_area),
            .status = try self.db.allocator.dupe(u8, "complete"),
            .recommended_lat = -18.1500,
            .recommended_lng = 13.7200,
            .confidence_score = 91,
            .justification = try self.db.allocator.dupe(u8, "High fracture lineament convergence and 800m proximity to local population."),
            .created_at = try self.db.allocator.dupe(u8, "2026-09-23T12:00:00Z"),
        };

        try self.db.siting_suggestions.append(self.db.allocator, sug);
        return sug;
    }

    pub fn getSuggestionById(self: AiService, id: []const u8) ?SitingSuggestion {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        for (self.db.siting_suggestions.items) |s| {
            if (std.mem.eql(u8, s.id, id)) {
                return s;
            }
        }
        return null;
    }

    pub fn predictYield(self: AiService, lat: f64, lng: f64, target_depth_m: f64) YieldInference {
        _ = self;
        return YieldInference.predict(lat, lng, target_depth_m);
    }

    pub fn simulateDepletion(self: AiService, daily_liters: u64, horizon_years: u16) DepletionSimulation {
        _ = self;
        return DepletionSimulation.simulate(daily_liters, horizon_years);
    }

    pub fn dispatchAsyncTask(self: AiService, target_area: []const u8) AsyncTaskStatus {
        return self.worker_client.dispatchAsyncSitingTask(target_area);
    }

    pub fn getTaskStatus(self: AiService, task_id: []const u8) AsyncTaskStatus {
        return self.worker_client.queryTaskStatus(task_id);
    }

    pub fn ingestDrillingLog(
        self: AiService,
        allocator: std.mem.Allocator,
        borehole_code: []const u8,
        lat: f64,
        lng: f64,
        total_depth_m: f64,
        strike_depth_m: f64,
        tested_yield: u32,
        static_level: f64,
    ) !struct { log_id: []const u8, borehole_code: []const u8 } {
        self.db.mutex.lock();
        defer self.db.mutex.unlock();

        const count = self.db.drilling_logs.items.len;
        const id = try Ids.formatDrillingLogId(allocator, count + 1);

        const log: BoreholeDrillingLog = .{
            .id = try self.db.allocator.dupe(u8, id),
            .borehole_code = try self.db.allocator.dupe(u8, borehole_code),
            .lat = lat,
            .lng = lng,
            .total_depth_m = total_depth_m,
            .water_strike_depth_m = strike_depth_m,
            .tested_yield_lph = tested_yield,
            .static_water_level_m = static_level,
            .created_at = try self.db.allocator.dupe(u8, "2026-09-23T12:00:00Z"),
        };

        try self.db.drilling_logs.append(self.db.allocator, log);
        return .{ .log_id = id, .borehole_code = borehole_code };
    }

    pub fn evaluateTerrain(self: AiService, vehicle_type: []const u8) TerrainFeasibility.Assessment {
        _ = self;
        return TerrainFeasibility.evaluate(vehicle_type);
    }
};
