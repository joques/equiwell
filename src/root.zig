const std = @import("std");

pub const app = @import("app/application.zig");
pub const config = @import("config/config.zig");
pub const errors = @import("errors/api_error.zig");
pub const observability = struct {
    pub const logger = @import("observability/logger.zig");
    pub const metrics = @import("observability/metrics.zig");
    pub const tracing = @import("observability/tracing.zig");
};

pub const models = struct {
    pub const user = @import("models/user.zig");
    pub const borehole = @import("models/borehole.zig");
    pub const health = @import("models/health.zig");
    pub const telemetry = @import("models/telemetry.zig");
    pub const allocation = @import("models/allocation.zig");
    pub const logistics = @import("models/logistics.zig");
    pub const community = @import("models/community.zig");
    pub const ai = @import("models/ai.zig");
};

pub const domain = struct {
    pub const hydrogeology = struct {
        pub const factors = @import("domain/hydrogeology/factors.zig");
        pub const mcda = @import("domain/hydrogeology/mcda.zig");
        pub const yield_prediction = @import("domain/hydrogeology/yield_prediction.zig");
        pub const depletion = @import("domain/hydrogeology/depletion.zig");
    };
    pub const equity = struct {
        pub const gini = @import("domain/equity/gini.zig");
        pub const water_stress = @import("domain/equity/water_stress.zig");
    };
    pub const terrain = struct {
        pub const feasibility = @import("domain/terrain/feasibility.zig");
    };
};

pub const auth = struct {
    pub const password = @import("auth/password.zig");
    pub const jwt = @import("auth/jwt.zig");
    pub const permissions = @import("auth/permissions.zig");
    pub const rbac = @import("auth/rbac.zig");
};

pub const database = @import("database/database.zig");

pub const repositories = struct {
    pub const user_repo = @import("repositories/user_repository.zig");
    pub const borehole_repo = @import("repositories/borehole_repository.zig");
    pub const lab_repo = @import("repositories/lab_repository.zig");
    pub const telemetry_repo = @import("repositories/telemetry_repository.zig");
    pub const allocation_repo = @import("repositories/allocation_repository.zig");
    pub const community_repo = @import("repositories/community_repository.zig");
};

pub const services = struct {
    pub const user_service = @import("services/user_service.zig");
    pub const borehole_service = @import("services/borehole_service.zig");
    pub const health_service = @import("services/health_service.zig");
    pub const telemetry_service = @import("services/telemetry_service.zig");
    pub const maintenance_service = @import("services/maintenance_service.zig");
    pub const allocation_service = @import("services/allocation_service.zig");
    pub const community_service = @import("services/community_service.zig");
    pub const logistics_service = @import("services/logistics_service.zig");
    pub const ai_service = @import("services/ai_service.zig");
};

pub const integrations = struct {
    pub const google_maps = @import("integrations/google_maps.zig");
    pub const ai_worker = @import("integrations/ai_worker.zig");
    pub const iot = @import("integrations/iot.zig");
};

pub const server = struct {
    pub const server = @import("server/server.zig");
    pub const router = @import("server/router.zig");
    pub const request = @import("server/request.zig");
    pub const response = @import("server/response.zig");
    pub const middleware = @import("server/middleware.zig");
    pub const cors = @import("server/cors.zig");
};

pub const utils = struct {
    pub const validation = @import("utils/validation.zig");
    pub const ids = @import("utils/ids.zig");
    pub const datetime = @import("utils/datetime.zig");
    pub const json = @import("utils/json.zig");
};

// =========================================================================
// UNIT TESTS
// =========================================================================

test "JWT generation and verification" {
    const allocator = std.testing.allocator;

    const token = try auth.jwt.generateToken(
        allocator,
        "USR-001",
        "Reinhold Ndevahoma",
        "rndevahoma@equiwell.nam",
        .admin,
    );
    defer allocator.free(token);

    try std.testing.expect(token.len > 0);

    var payload = auth.jwt.verifyToken(allocator, token);
    try std.testing.expect(payload != null);
    if (payload) |*p| {
        defer p.deinit(allocator);
        try std.testing.expectEqualStrings("USR-001", p.sub);
        try std.testing.expectEqualStrings("Reinhold Ndevahoma", p.name);
        try std.testing.expectEqualStrings("rndevahoma@equiwell.nam", p.email);
        try std.testing.expectEqual(models.user.UserRole.admin, p.role);
    }
}

test "Password PBKDF2 hashing and verification" {
    const allocator = std.testing.allocator;
    const pwd = "SecurePassword123!";

    const hashed = try auth.password.Password.hash(allocator, pwd);
    defer allocator.free(hashed);

    try std.testing.expect(auth.password.Password.verify(pwd, hashed));
    try std.testing.expect(!auth.password.Password.verify("WrongPassword", hashed));
}

test "Gini Coefficient Calculation" {
    const values = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const gini = domain.equity.gini.Gini.computeGini(&values);
    try std.testing.expect(gini > 0.0 and gini < 1.0);
}

test "MCDA Groundwater Suitability Calculation" {
    const suitability = domain.hydrogeology.mcda.Mcda.calculateSuitability(0.9, 0.8, 0.7, 0.85);
    const confidence = domain.hydrogeology.mcda.Mcda.computeConfidenceScore(suitability);
    try std.testing.expect(confidence > 70);
}

test "Input Validation helper functions" {
    const Val = utils.validation.Validation;

    // Coordinate validation & finite floats
    try std.testing.expect(Val.isValidCoordinates(-18.0583, 13.8402));
    try std.testing.expect(!Val.isValidCoordinates(-95.0, 13.0));
    try std.testing.expect(!Val.isValidCoordinates(18.0, 185.0));
    try std.testing.expect(!Val.isValidCoordinates(std.math.nan(f64), 13.0));
    try std.testing.expect(!Val.isValidCoordinates(18.0, std.math.inf(f64)));

    // Email validation
    try std.testing.expect(Val.isValidEmail("rndevahoma@equiwell.nam"));
    try std.testing.expect(!Val.isValidEmail("invalid-email"));
    try std.testing.expect(!Val.isValidEmail("user@.com"));
    try std.testing.expect(!Val.isValidEmail("user@domain..com"));
    try std.testing.expect(!Val.isValidEmail("user name@domain.com"));

    // Password validation
    try std.testing.expect(Val.isValidPassword("SecurePassword123!"));
    try std.testing.expect(!Val.isValidPassword("short"));
    const long_pwd: [129]u8 = @splat('a');
    try std.testing.expect(!Val.isValidPassword(&long_pwd));

    // Date validation (calendar integrity & leap year rules)
    try std.testing.expect(Val.isValidDate("2026-08-19"));
    try std.testing.expect(Val.isValidDate("2024-02-29")); // Valid leap year
    try std.testing.expect(Val.isValidDate("2026-02-28")); // Valid common year Feb
    try std.testing.expect(Val.isValidDate("2026-04-30")); // Valid April 30
    try std.testing.expect(Val.isValidDate("2026-12-31")); // Valid Dec 31
    try std.testing.expect(!Val.isValidDate("2026-02-29")); // Invalid: 2026 not leap
    try std.testing.expect(!Val.isValidDate("2025-02-29")); // Invalid: 2025 not leap
    try std.testing.expect(!Val.isValidDate("2026-04-31")); // Invalid: April has 30 days
    try std.testing.expect(!Val.isValidDate("2026-06-31")); // Invalid: June has 30 days
    try std.testing.expect(!Val.isValidDate("2026-09-31")); // Invalid: September has 30 days
    try std.testing.expect(!Val.isValidDate("2026-11-31")); // Invalid: November has 30 days
    try std.testing.expect(!Val.isValidDate("2026-00-15")); // Invalid: month 00
    try std.testing.expect(!Val.isValidDate("2026-13-19")); // Invalid: month 13
    try std.testing.expect(!Val.isValidDate("2026-05-00")); // Invalid: day 00
    try std.testing.expect(!Val.isValidDate("2026-08-32")); // Invalid: day 32
    try std.testing.expect(!Val.isValidDate("invalid-date"));

    // Percentage & Positive float bounds
    try std.testing.expect(Val.isValidPercentage(100));
    try std.testing.expect(!Val.isValidPercentage(101));
    try std.testing.expect(Val.isValidPositiveFloat(50.5, 1000.0));
    try std.testing.expect(!Val.isValidPositiveFloat(-1.0, 1000.0));
    try std.testing.expect(!Val.isValidPositiveFloat(1001.0, 1000.0));

    // Urgency validation
    try std.testing.expect(Val.isValidUrgency("critical"));
    try std.testing.expect(!Val.isValidUrgency("apocalyptic"));
}

test "Metrics initialization and request recording" {
    var m = observability.metrics.Metrics.init();

    // Start request
    const t0 = m.recordRequestStart();
    try std.testing.expectEqual(@as(u64, 1), m.total_requests.load(.monotonic));
    try std.testing.expectEqual(@as(i64, 1), m.active_requests.load(.monotonic));
    try std.testing.expectEqual(@as(u64, 1), m.peak_active_requests.load(.monotonic));

    // Complete 200 OK
    m.recordRequestComplete(t0, 200, 128, 512, false);
    try std.testing.expectEqual(@as(i64, 0), m.active_requests.load(.monotonic));
    try std.testing.expectEqual(@as(u64, 1), m.successful_requests.load(.monotonic));
    try std.testing.expectEqual(@as(u64, 128), m.total_request_bytes.load(.monotonic));
    try std.testing.expectEqual(@as(u64, 512), m.total_response_bytes.load(.monotonic));

    // Record 400 Bad Request
    const t1 = m.recordRequestStart();
    m.recordRequestComplete(t1, 400, 50, 80, false);
    try std.testing.expectEqual(@as(u64, 1), m.validation_failures.load(.monotonic));
    try std.testing.expectEqual(@as(u64, 1), m.client_error_requests.load(.monotonic));

    // Record 401 Unauthorized
    const t2 = m.recordRequestStart();
    m.recordRequestComplete(t2, 401, 50, 80, false);
    try std.testing.expectEqual(@as(u64, 1), m.authentication_failures.load(.monotonic));

    // Record 403 Forbidden
    const t3 = m.recordRequestStart();
    m.recordRequestComplete(t3, 403, 50, 80, false);
    try std.testing.expectEqual(@as(u64, 1), m.authorization_denials.load(.monotonic));

    // Record 413 Payload Too Large (Security Rejection)
    const t4 = m.recordRequestStart();
    m.recordRequestComplete(t4, 413, 100, 100, true);
    try std.testing.expectEqual(@as(u64, 1), m.rate_or_security_rejections.load(.monotonic));

    // Record 500 Internal Error
    const t5 = m.recordRequestStart();
    m.recordRequestComplete(t5, 500, 50, 80, false);
    try std.testing.expectEqual(@as(u64, 1), m.server_error_requests.load(.monotonic));

    // Queue rejection
    m.recordQueueRejection();
    try std.testing.expectEqual(@as(u64, 1), m.queue_rejections.load(.monotonic));

    // Task completions
    m.recordWorkerTaskCompleted();
    m.recordWorkerTaskFailed();
    try std.testing.expectEqual(@as(u64, 1), m.worker_tasks_completed.load(.monotonic));
    try std.testing.expectEqual(@as(u64, 1), m.worker_tasks_failed.load(.monotonic));
}

test "Metrics JSON serialization and secret isolation" {
    const allocator = std.testing.allocator;
    var m = observability.metrics.Metrics.init();

    const t0 = m.recordRequestStart();
    m.recordRequestComplete(t0, 200, 100, 200, false);

    const json = try m.formatJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(json.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"total_requests\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"successful_requests\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"uptime_seconds\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"average_latency_ms\":") != null);

    // Verify ZERO sensitive keys are leaked
    try std.testing.expect(std.mem.indexOf(u8, json, "password") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "token") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Authorization") == null);
}
