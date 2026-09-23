const std = @import("std");
const User = @import("../models/user.zig").User;
const Borehole = @import("../models/borehole.zig").Borehole;
const LabTest = @import("../models/health.zig").LabTest;
const TelemetryRecord = @import("../models/telemetry.zig").TelemetryRecord;
const MaintenanceAlert = @import("../models/telemetry.zig").MaintenanceAlert;
const CommunityRequest = @import("../models/community.zig").CommunityRequest;
const SitingSuggestion = @import("../models/ai.zig").SitingSuggestion;
const BoreholeDrillingLog = @import("../models/ai.zig").BoreholeDrillingLog;
const SeedData = @import("seed.zig").SeedData;

/// Lightweight atomic spinlock mutex for safe concurrent database access.
pub const Mutex = struct {
    state: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn lock(self: *Mutex) void {
        while (self.state.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *Mutex) void {
        self.state.store(false, .release);
    }
};

/// Thread-safe in-memory database engine for the EquiWell platform.
pub const Database = struct {
    allocator: std.mem.Allocator,
    mutex: Mutex = .{},

    users: std.ArrayList(User),
    boreholes: std.ArrayList(Borehole),
    lab_tests: std.ArrayList(LabTest),
    telemetry_records: std.ArrayList(TelemetryRecord),
    maintenance_alerts: std.ArrayList(MaintenanceAlert),
    community_requests: std.ArrayList(CommunityRequest),
    siting_suggestions: std.ArrayList(SitingSuggestion),
    drilling_logs: std.ArrayList(BoreholeDrillingLog),

    pub fn init(allocator: std.mem.Allocator) !*Database {
        const self = try allocator.create(Database);
        self.* = .{
            .allocator = allocator,
            .users = .empty,
            .boreholes = .empty,
            .lab_tests = .empty,
            .telemetry_records = .empty,
            .maintenance_alerts = .empty,
            .community_requests = .empty,
            .siting_suggestions = .empty,
            .drilling_logs = .empty,
        };

        try SeedData.seedUsers(allocator, &self.users);
        try SeedData.seedBoreholes(allocator, &self.boreholes);
        try SeedData.seedLabTests(allocator, &self.lab_tests);
        try SeedData.seedAlerts(allocator, &self.maintenance_alerts);
        try SeedData.seedCommunityRequests(allocator, &self.community_requests);
        try SeedData.seedSuggestions(allocator, &self.siting_suggestions);

        return self;
    }

    pub fn deinit(self: *Database) void {
        self.users.deinit(self.allocator);
        self.boreholes.deinit(self.allocator);
        self.lab_tests.deinit(self.allocator);
        self.telemetry_records.deinit(self.allocator);
        self.maintenance_alerts.deinit(self.allocator);
        self.community_requests.deinit(self.allocator);
        self.siting_suggestions.deinit(self.allocator);
        self.drilling_logs.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};
