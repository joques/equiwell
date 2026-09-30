const std = @import("std");

extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *i64) callconv(std.builtin.CallingConvention.winapi) i32;
extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *i64) callconv(std.builtin.CallingConvention.winapi) i32;
extern "kernel32" fn GetSystemTimeAsFileTime(lpSystemTimeAsFileTime: *u64) callconv(std.builtin.CallingConvention.winapi) void;

var qpc_freq: std.atomic.Value(i64) = std.atomic.Value(i64).init(0);

/// Returns monotonic time in nanoseconds using Windows QueryPerformanceCounter (QPC).
pub fn getMonotonicNs() i128 {
    var count: i64 = 0;
    _ = QueryPerformanceCounter(&count);

    var freq = qpc_freq.load(.monotonic);
    if (freq == 0) {
        var f: i64 = 0;
        _ = QueryPerformanceFrequency(&f);
        if (f > 0) {
            qpc_freq.store(f, .monotonic);
            freq = f;
        } else {
            freq = 10_000_000; // Fallback 10MHz
        }
    }

    const c: i128 = count;
    const f: i128 = freq;
    return @divTrunc(c * std.time.ns_per_s, f);
}

/// Returns current Unix epoch timestamp in seconds.
pub fn getUnixTimestamp() i64 {
    var ft: u64 = 0;
    GetSystemTimeAsFileTime(&ft);
    const epoch_diff: u64 = 116444736000000000; // 100-ns intervals between 1601-01-01 and 1970-01-01
    if (ft >= epoch_diff) {
        const unix_100ns = ft - epoch_diff;
        return @intCast(unix_100ns / 10_000_000);
    }
    return 0;
}

/// High-performance, lock-free operational metrics collector.
///
/// Implements centralized atomic counters and monotonic latency measurement
/// with zero heap allocations on recording hot paths.
pub const Metrics = struct {
    // Request & Status Counters
    total_requests: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    successful_requests: std.atomic.Value(u64) = std.atomic.Value(u64).init(0), // 2xx
    client_error_requests: std.atomic.Value(u64) = std.atomic.Value(u64).init(0), // 4xx
    server_error_requests: std.atomic.Value(u64) = std.atomic.Value(u64).init(0), // 5xx

    // Detailed Error & Security Counters
    authentication_failures: std.atomic.Value(u64) = std.atomic.Value(u64).init(0), // 401
    authorization_denials: std.atomic.Value(u64) = std.atomic.Value(u64).init(0), // 403
    validation_failures: std.atomic.Value(u64) = std.atomic.Value(u64).init(0), // 400
    rate_or_security_rejections: std.atomic.Value(u64) = std.atomic.Value(u64).init(0), // 413, 431, 503, smuggling

    // Concurrency & Active Request Tracking
    active_requests: std.atomic.Value(i64) = std.atomic.Value(i64).init(0),
    peak_active_requests: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    // Monotonic Timing & Latency Accumulation
    total_request_duration_ns: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    // Bandwidth / IO Accounting
    total_request_bytes: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    total_response_bytes: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    // Worker Pool Metrics
    worker_tasks_completed: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    worker_tasks_failed: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),
    queue_rejections: std.atomic.Value(u64) = std.atomic.Value(u64).init(0),

    // Process Start Timestamps
    start_time_ns: i128 = 0,
    start_time_utc: i64 = 0,

    pub fn init() Metrics {
        return .{
            .start_time_ns = getMonotonicNs(),
            .start_time_utc = getUnixTimestamp(),
        };
    }

    /// Records the start of an incoming request.
    /// Returns the monotonic timestamp in nanoseconds for duration computation.
    pub fn recordRequestStart(self: *Metrics) i128 {
        _ = self.total_requests.fetchAdd(1, .monotonic);
        const curr_active = self.active_requests.fetchAdd(1, .monotonic) + 1;
        if (curr_active > 0) {
            const u_active: u64 = @intCast(curr_active);
            var current_peak = self.peak_active_requests.load(.monotonic);
            while (u_active > current_peak) {
                current_peak = self.peak_active_requests.cmpxchgWeak(current_peak, u_active, .monotonic, .monotonic) orelse break;
            }
        }
        return getMonotonicNs();
    }

    /// Records request completion, status code categorization, and latency.
    pub fn recordRequestComplete(
        self: *Metrics,
        start_time_ns: i128,
        status_code: u16,
        req_bytes: usize,
        res_bytes: usize,
        is_security_rejection: bool,
    ) void {
        _ = self.active_requests.fetchSub(1, .monotonic);

        const now_ns = getMonotonicNs();
        const elapsed_ns: u64 = if (now_ns > start_time_ns) @intCast(now_ns - start_time_ns) else 0;
        _ = self.total_request_duration_ns.fetchAdd(elapsed_ns, .monotonic);

        _ = self.total_request_bytes.fetchAdd(@intCast(req_bytes), .monotonic);
        _ = self.total_response_bytes.fetchAdd(@intCast(res_bytes), .monotonic);

        if (status_code >= 200 and status_code < 300) {
            _ = self.successful_requests.fetchAdd(1, .monotonic);
        } else if (status_code == 400) {
            _ = self.validation_failures.fetchAdd(1, .monotonic);
            _ = self.client_error_requests.fetchAdd(1, .monotonic);
        } else if (status_code == 401) {
            _ = self.authentication_failures.fetchAdd(1, .monotonic);
            _ = self.client_error_requests.fetchAdd(1, .monotonic);
        } else if (status_code == 403) {
            _ = self.authorization_denials.fetchAdd(1, .monotonic);
            _ = self.client_error_requests.fetchAdd(1, .monotonic);
        } else if (status_code >= 400 and status_code < 500) {
            _ = self.client_error_requests.fetchAdd(1, .monotonic);
        } else if (status_code >= 500) {
            _ = self.server_error_requests.fetchAdd(1, .monotonic);
        }

        if (is_security_rejection or status_code == 413 or status_code == 431 or status_code == 503) {
            _ = self.rate_or_security_rejections.fetchAdd(1, .monotonic);
        }
    }

    /// Records worker pool queue saturation / backpressure rejection.
    pub fn recordQueueRejection(self: *Metrics) void {
        _ = self.queue_rejections.fetchAdd(1, .monotonic);
        _ = self.rate_or_security_rejections.fetchAdd(1, .monotonic);
        _ = self.server_error_requests.fetchAdd(1, .monotonic);
    }

    /// Records successful worker task execution.
    pub fn recordWorkerTaskCompleted(self: *Metrics) void {
        _ = self.worker_tasks_completed.fetchAdd(1, .monotonic);
    }

    /// Records worker task processing failure.
    pub fn recordWorkerTaskFailed(self: *Metrics) void {
        _ = self.worker_tasks_failed.fetchAdd(1, .monotonic);
    }

    /// Computes process uptime in seconds using monotonic clock.
    pub fn getUptimeSeconds(self: *const Metrics) u64 {
        const now = getMonotonicNs();
        if (now > self.start_time_ns and self.start_time_ns != 0) {
            const diff: u64 = @intCast(now - self.start_time_ns);
            return diff / std.time.ns_per_s;
        }
        return 0;
    }

    /// Formats an aggregate, thread-safe JSON snapshot containing zero credentials or sensitive data.
    pub fn formatJson(self: *const Metrics, allocator: std.mem.Allocator) ![]const u8 {
        const total_req = self.total_requests.load(.monotonic);
        const success_req = self.successful_requests.load(.monotonic);
        const client_err = self.client_error_requests.load(.monotonic);
        const server_err = self.server_error_requests.load(.monotonic);
        const auth_fail = self.authentication_failures.load(.monotonic);
        const auth_denial = self.authorization_denials.load(.monotonic);
        const val_fail = self.validation_failures.load(.monotonic);
        const sec_rejections = self.rate_or_security_rejections.load(.monotonic);
        const active_raw = self.active_requests.load(.monotonic);
        const active_req: u64 = if (active_raw > 0) @intCast(active_raw) else 0;
        const peak_active = self.peak_active_requests.load(.monotonic);
        const total_dur_ns = self.total_request_duration_ns.load(.monotonic);
        const req_bytes = self.total_request_bytes.load(.monotonic);
        const res_bytes = self.total_response_bytes.load(.monotonic);
        const tasks_comp = self.worker_tasks_completed.load(.monotonic);
        const tasks_fail = self.worker_tasks_failed.load(.monotonic);
        const queue_rej = self.queue_rejections.load(.monotonic);
        const uptime = self.getUptimeSeconds();

        const total_dur_ms: f64 = @as(f64, @floatFromInt(total_dur_ns)) / 1_000_000.0;
        const avg_latency_ms: f64 = if (total_req > 0) total_dur_ms / @as(f64, @floatFromInt(total_req)) else 0.0;

        return std.fmt.allocPrint(allocator,
            "{{" ++
                "\"uptime_seconds\":{d}," ++
                "\"total_requests\":{d}," ++
                "\"successful_requests\":{d}," ++
                "\"client_error_requests\":{d}," ++
                "\"server_error_requests\":{d}," ++
                "\"authentication_failures\":{d}," ++
                "\"authorization_denials\":{d}," ++
                "\"validation_failures\":{d}," ++
                "\"rate_or_security_rejections\":{d}," ++
                "\"active_requests\":{d}," ++
                "\"peak_active_requests\":{d}," ++
                "\"average_latency_ms\":{d:.4}," ++
                "\"total_request_duration_ms\":{d:.4}," ++
                "\"total_request_bytes\":{d}," ++
                "\"total_response_bytes\":{d}," ++
                "\"worker_tasks_completed\":{d}," ++
                "\"worker_tasks_failed\":{d}," ++
                "\"queue_rejections\":{d}" ++
                "}}",
            .{
                uptime,
                total_req,
                success_req,
                client_err,
                server_err,
                auth_fail,
                auth_denial,
                val_fail,
                sec_rejections,
                active_req,
                peak_active,
                avg_latency_ms,
                total_dur_ms,
                req_bytes,
                res_bytes,
                tasks_comp,
                tasks_fail,
                queue_rej,
            },
        );
    }
};

pub const default_metrics: Metrics = .{};
