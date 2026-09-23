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
