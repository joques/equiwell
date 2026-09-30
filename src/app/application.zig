const std = @import("std");
const Config = @import("../config/config.zig").Config;
const Logger = @import("../observability/logger.zig").Logger;
const Metrics = @import("../observability/metrics.zig").Metrics;
const Database = @import("../database/database.zig").Database;

// Repositories
const UserRepository = @import("../repositories/user_repository.zig").UserRepository;
const BoreholeRepository = @import("../repositories/borehole_repository.zig").BoreholeRepository;
const LabRepository = @import("../repositories/lab_repository.zig").LabRepository;
const TelemetryRepository = @import("../repositories/telemetry_repository.zig").TelemetryRepository;
const AllocationRepository = @import("../repositories/allocation_repository.zig").AllocationRepository;
const CommunityRepository = @import("../repositories/community_repository.zig").CommunityRepository;

// Integrations
const GoogleMapsAdapter = @import("../integrations/google_maps.zig").GoogleMapsAdapter;
const AiWorkerClient = @import("../integrations/ai_worker.zig").AiWorkerClient;

// Services
const UserService = @import("../services/user_service.zig").UserService;
const BoreholeService = @import("../services/borehole_service.zig").BoreholeService;
const HealthService = @import("../services/health_service.zig").HealthService;
const TelemetryService = @import("../services/telemetry_service.zig").TelemetryService;
const MaintenanceService = @import("../services/maintenance_service.zig").MaintenanceService;
const AllocationService = @import("../services/allocation_service.zig").AllocationService;
const CommunityService = @import("../services/community_service.zig").CommunityService;
const LogisticsService = @import("../services/logistics_service.zig").LogisticsService;
const AiService = @import("../services/ai_service.zig").AiService;

// Auth & Server
const JwtManager = @import("../auth/jwt.zig").JwtManager;
const Middleware = @import("../server/middleware.zig").Middleware;
const Router = @import("../server/router.zig").Router;
const Server = @import("../server/server.zig").Server;

/// Dependency Injection Container and Application Lifecycle Coordinator.
pub const Application = struct {
    allocator: std.mem.Allocator,
    config: Config,
    logger: Logger,
    metrics: Metrics,
    db: *Database,

    // Repositories
    user_repo: UserRepository,
    borehole_repo: BoreholeRepository,
    lab_repo: LabRepository,
    telemetry_repo: TelemetryRepository,
    allocation_repo: AllocationRepository,
    community_repo: CommunityRepository,

    // Integrations
    gmaps_adapter: GoogleMapsAdapter,
    ai_worker_client: AiWorkerClient,

    // Services
    user_service: UserService,
    borehole_service: BoreholeService,
    health_service: HealthService,
    telemetry_service: TelemetryService,
    maintenance_service: MaintenanceService,
    allocation_service: AllocationService,
    community_service: CommunityService,
    logistics_service: LogisticsService,
    ai_service: AiService,

    // Auth & Transport
    jwt_mgr: JwtManager,
    middleware: Middleware,
    router: Router,
    server: Server,

    pub fn create(allocator: std.mem.Allocator) !*Application {
        const self = try allocator.create(Application);

        self.allocator = allocator;
        self.config = Config.initFromEnv(allocator);
        self.logger = Logger.init(.info);
        self.metrics = Metrics.init();
        self.db = try Database.init(allocator);

        // Repositories
        self.user_repo = UserRepository.init(self.db);
        self.borehole_repo = BoreholeRepository.init(self.db);
        self.lab_repo = LabRepository.init(self.db);
        self.telemetry_repo = TelemetryRepository.init(self.db);
        self.allocation_repo = AllocationRepository.init(self.db);
        self.community_repo = CommunityRepository.init(self.db);

        // Integrations
        self.gmaps_adapter = GoogleMapsAdapter.init(self.config.google_maps_api_key);
        self.ai_worker_client = AiWorkerClient.init(self.config.ai_worker_url);

        // Auth
        self.jwt_mgr = JwtManager.init(self.config.jwt_secret, self.config.token_expiry_seconds);
        self.middleware = Middleware.init(self.jwt_mgr);

        // Services
        self.user_service = UserService.init(self.user_repo, self.jwt_mgr);
        self.borehole_service = BoreholeService.init(self.borehole_repo);
        self.health_service = HealthService.init(self.lab_repo, self.borehole_repo);
        self.telemetry_service = TelemetryService.init(self.telemetry_repo, self.borehole_repo);
        self.maintenance_service = MaintenanceService.init(self.telemetry_repo, self.borehole_repo);
        self.allocation_service = AllocationService.init(self.allocation_repo);
        self.community_service = CommunityService.init(self.community_repo);
        self.logistics_service = LogisticsService.init(self.borehole_repo, self.gmaps_adapter);
        self.ai_service = AiService.init(self.db, self.ai_worker_client);

        // Router
        self.router = Router.init(
            &self.user_service,
            &self.borehole_service,
            &self.health_service,
            &self.telemetry_service,
            &self.maintenance_service,
            &self.allocation_service,
            &self.community_service,
            &self.logistics_service,
            &self.ai_service,
            &self.metrics,
        );

        // Server
        self.server = Server.init(
            allocator,
            self.config,
            &self.router,
            self.middleware,
            self.logger,
            &self.metrics,
        );

        return self;
    }

    pub fn start(self: *Application) !void {
        try self.server.start();
    }

    pub fn destroy(self: *Application) void {
        self.db.deinit();
        self.allocator.destroy(self);
    }
};
