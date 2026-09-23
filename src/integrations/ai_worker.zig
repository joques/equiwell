const std = @import("std");
const AsyncTaskStatus = @import("../models/ai.zig").AsyncTaskStatus;

/// Adapter client for dispatching and querying asynchronous AI computation jobs.
pub const AiWorkerClient = struct {
    worker_url: []const u8 = "http://127.0.0.1:5000",

    pub fn init(worker_url: []const u8) AiWorkerClient {
        return .{ .worker_url = worker_url };
    }

    pub fn dispatchAsyncSitingTask(self: AiWorkerClient, target_area: []const u8) AsyncTaskStatus {
        _ = self;
        return .{
            .task_id = "TASK-AI-7721",
            .status = "QUEUED",
            .target_area = target_area,
            .created_at = "2026-09-23T12:00:00Z",
        };
    }

    pub fn queryTaskStatus(self: AiWorkerClient, task_id: []const u8) AsyncTaskStatus {
        _ = self;
        return .{
            .task_id = task_id,
            .status = "completed",
            .target_area = "Epupa",
            .created_at = "2026-09-23T12:00:00Z",
            .completed_at = "2026-09-23T12:01:15Z",
        };
    }
};
