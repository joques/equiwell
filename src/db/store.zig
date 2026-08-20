const std = @import("std");
const User = @import("../models/user.zig").User;
const UserRole = @import("../models/user.zig").UserRole;
const Borehole = @import("../models/borehole.zig").Borehole;
const PumpType = @import("../models/borehole.zig").PumpType;
const BoreholeStatus = @import("../models/borehole.zig").BoreholeStatus;
const LabTest = @import("../models/health.zig").LabTest;
const TelemetryRecord = @import("../models/telemetry.zig").TelemetryRecord;
const MaintenanceAlert = @import("../models/telemetry.zig").MaintenanceAlert;
const CommunityRequest = @import("../models/allocation.zig").CommunityRequest;
const SitingSuggestion = @import("../models/ai_siting.zig").SitingSuggestion;
const BoreholeDrillingLog = @import("../models/ai_siting.zig").BoreholeDrillingLog;
const password_auth = @import("../auth/password.zig");

/// Lightweight atomic spinlock mutex for cross-platform thread synchronization without libc dependencies.
pub const Mutex = struct {
    state: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    /// Acquires the lock, spinning until the atomic lock is obtained.
    pub fn lock(self: *Mutex) void {
        while (self.state.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }

    /// Releases the lock.
    pub fn unlock(self: *Mutex) void {
        self.state.store(false, .release);
    }
};

/// Thread-safe in-memory datastore containing all domain entities for the EquiWell platform.
pub const DataStore = struct {
    allocator: std.mem.Allocator,
    mutex: Mutex = .{},

    users: std.ArrayList(User),
    boreholes: std.ArrayList(Borehole),
    lab_tests: std.ArrayList(LabTest),
    telemetry: std.ArrayList(TelemetryRecord),
    alerts: std.ArrayList(MaintenanceAlert),
    community_requests: std.ArrayList(CommunityRequest),
    siting_suggestions: std.ArrayList(SitingSuggestion),
    drilling_logs: std.ArrayList(BoreholeDrillingLog),

    /// Initializes the DataStore and populates it with verified Kunene Region seed fixtures.
    pub fn init(allocator: std.mem.Allocator) !*DataStore {
        const self = try allocator.create(DataStore);
        self.* = .{
            .allocator = allocator,
            .mutex = .{},
            .users = std.ArrayList(User).empty,
            .boreholes = std.ArrayList(Borehole).empty,
            .lab_tests = std.ArrayList(LabTest).empty,
            .telemetry = std.ArrayList(TelemetryRecord).empty,
            .alerts = std.ArrayList(MaintenanceAlert).empty,
            .community_requests = std.ArrayList(CommunityRequest).empty,
            .siting_suggestions = std.ArrayList(SitingSuggestion).empty,
            .drilling_logs = std.ArrayList(BoreholeDrillingLog).empty,
        };

        try self.seedInitialData();
        return self;
    }

    /// Releases all heap-allocated structures in the DataStore.
    pub fn deinit(self: *DataStore) void {
        self.users.deinit(self.allocator);
        self.boreholes.deinit(self.allocator);
        self.lab_tests.deinit(self.allocator);
        self.telemetry.deinit(self.allocator);
        self.alerts.deinit(self.allocator);
        self.community_requests.deinit(self.allocator);
        self.siting_suggestions.deinit(self.allocator);
        self.drilling_logs.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Seeds realistic sample data representing boreholes and users across the Kunene Region.
    fn seedInitialData(self: *DataStore) !void {
        // Pre-computed SHA-256 hash for "SecurePassword123!"
        const default_hash = "b926e929192ee30e047ab90fc9d1e0d811a4ccc5f0411da2047abfccc8cd8f60";

        // Seed Users
        try self.users.append(self.allocator, .{
            .id = "USR-001",
            .name = "Reinhold Ndevahoma",
            .email = "rndevahoma@equiwell.nam",
            .password_hash = default_hash,
            .role = .admin,
            .created_at = "2026-08-19T08:00:00Z",
        });

        try self.users.append(self.allocator, .{
            .id = "USR-002",
            .name = "Maria Shikongo",
            .email = "mshikongo@health.nam.gov",
            .password_hash = default_hash,
            .role = .health_inspector,
            .created_at = "2026-08-19T08:30:00Z",
        });

        try self.users.append(self.allocator, .{
            .id = "USR-003",
            .name = "Petrus Amukwaya",
            .email = "pamukwaya@maintenance.nam",
            .password_hash = default_hash,
            .role = .maintenance_crew,
            .created_at = "2026-08-19T09:00:00Z",
        });

        try self.users.append(self.allocator, .{
            .id = "USR-004",
            .name = "Chief Kampi",
            .email = "chief.kampi@kunene.nam",
            .password_hash = default_hash,
            .role = .community_leader,
            .created_at = "2026-08-19T09:30:00Z",
        });

        try self.users.append(self.allocator, .{
            .id = "USR-005",
            .name = "Public Viewer",
            .email = "viewer@equiwell.nam",
            .password_hash = default_hash,
            .role = .viewer,
            .created_at = "2026-08-19T10:00:00Z",
        });

        // Seed Boreholes
        try self.boreholes.append(self.allocator, .{
            .id = "BH-1001",
            .name = "Opuwo Central Solar Well",
            .lat = -18.0583,
            .lng = 13.8402,
            .depth_m = 92.0,
            .pump_type = .solar,
            .yield_lph = 2200,
            .status = .working,
            .water_quality = "potable",
            .implemented_date = "2023-06-10",
            .last_maintained = "2026-04-12",
            .is_visible = true,
            .installed_by = "Ministry of Agriculture, Water and Land Reform",
        });

        try self.boreholes.append(self.allocator, .{
            .id = "BH-1002",
            .name = "Okangwati Community Well 1",
            .lat = -18.2341,
            .lng = 13.8821,
            .depth_m = 85.0,
            .pump_type = .solar,
            .yield_lph = 1500,
            .status = .working,
            .water_quality = "potable",
            .implemented_date = "2024-03-15",
            .last_maintained = "2026-05-12",
            .is_visible = true,
            .installed_by = "EquiWell Field Team",
        });

        try self.boreholes.append(self.allocator, .{
            .id = "BH-1003",
            .name = "Sesfontein Primary Borehole",
            .lat = -19.1205,
            .lng = 13.6198,
            .depth_m = 110.0,
            .pump_type = .diesel,
            .yield_lph = 800,
            .status = .broken,
            .water_quality = "brackish",
            .implemented_date = "2021-11-20",
            .last_maintained = "2025-10-04",
            .is_visible = true,
            .installed_by = "Kunene Regional Council",
        });

        try self.boreholes.append(self.allocator, .{
            .id = "BH-1004",
            .name = "Epupa Falls Rural Hand Pump",
            .lat = -17.0012,
            .lng = 13.2456,
            .depth_m = 45.0,
            .pump_type = .hand_pump,
            .yield_lph = 450,
            .status = .maintenance_required,
            .water_quality = "potable",
            .implemented_date = "2022-08-01",
            .last_maintained = "2026-01-15",
            .is_visible = false,
            .installed_by = "NGO WaterAid Namibia",
        });

        // Seed Lab Tests
        try self.lab_tests.append(self.allocator, .{
            .id = "LAB-2026-081",
            .borehole_id = "BH-1002",
            .inspector_id = "USR-002",
            .test_date = "2026-07-20",
            .e_coli_detected = false,
            .arsenic_mg_l = 0.004,
            .fluoride_mg_l = 1.10,
            .is_safe_for_consumption = true,
        });

        // Seed Maintenance Alerts
        try self.alerts.append(self.allocator, .{
            .borehole_id = "BH-1003",
            .borehole_name = "Sesfontein Primary Borehole",
            .status = "broken",
            .issue = "Diesel engine cylinder head cracked; zero water delivery",
            .reported_at = "2026-08-18T14:30:00Z",
            .urgency = "critical",
        });

        try self.alerts.append(self.allocator, .{
            .borehole_id = "BH-1004",
            .borehole_name = "Epupa Falls Rural Hand Pump",
            .status = "maintenance_required",
            .issue = "Leaking mechanical seal and worn piston rod",
            .reported_at = "2026-08-19T07:15:00Z",
            .urgency = "high",
        });

        // Seed Community Requests
        try self.community_requests.append(self.allocator, .{
            .id = "COM-REQ-101",
            .community_name = "Otjondeka Village",
            .contact_person = "Headman Tjambiru",
            .contact_phone = "+264 81 555 1234",
            .issue = "Primary well yield dropped below 100 L/h; pastoral livestock in critical distress.",
            .urgency = "critical",
            .status = "under_review",
            .submitted_at = "2026-08-18T11:00:00Z",
        });

        // Seed AI Siting Suggestion
        try self.siting_suggestions.append(self.allocator, .{
            .id = "SUG-1001",
            .target_area = "Okangwati",
            .required_yield = "moderate",
            .priority_metric = "fair_allocation_distance",
            .status = "complete",
            .recommended_lat = -18.2100,
            .recommended_lng = 13.8500,
            .confidence_score = 92,
            .justification = "High fracture lineament convergence and 800m proximity to underserved population.",
            .created_at = "2026-08-19T06:00:00Z",
        });
    }

    /// Finds a user record by email address.
    pub fn findUserByEmail(self: *DataStore, email: []const u8) ?User {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.users.items) |u| {
            if (std.mem.eql(u8, u.email, email)) {
                return u;
            }
        }
        return null;
    }

    /// Finds a user record by unique identifier.
    pub fn findUserById(self: *DataStore, id: []const u8) ?User {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.users.items) |u| {
            if (std.mem.eql(u8, u.id, id)) {
                return u;
            }
        }
        return null;
    }

    /// Inserts a new user record into the store.
    pub fn addUser(self: *DataStore, user: User) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.users.append(self.allocator, user);
    }

    /// Updates an existing user's profile details.
    pub fn updateUser(self: *DataStore, id: []const u8, name: []const u8, email: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.users.items) |*u| {
            if (std.mem.eql(u8, u.id, id)) {
                u.name = try self.allocator.dupe(u8, name);
                u.email = try self.allocator.dupe(u8, email);
                return true;
            }
        }
        return false;
    }

    /// Updates a user's assigned RBAC role.
    pub fn updateUserRole(self: *DataStore, id: []const u8, role: UserRole) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.users.items) |*u| {
            if (std.mem.eql(u8, u.id, id)) {
                u.role = role;
                return true;
            }
        }
        return false;
    }

    /// Deletes a user record by ID.
    pub fn deleteUser(self: *DataStore, id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.users.items, 0..) |u, i| {
            if (std.mem.eql(u8, u.id, id)) {
                _ = self.users.swapRemove(i);
                return true;
            }
        }
        return false;
    }

    /// Finds a borehole by code ID.
    pub fn findBoreholeById(self: *DataStore, id: []const u8) ?Borehole {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.boreholes.items) |b| {
            if (std.mem.eql(u8, b.id, id)) {
                return b;
            }
        }
        return null;
    }

    /// Adds a new borehole record.
    pub fn addBorehole(self: *DataStore, borehole: Borehole) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.boreholes.append(self.allocator, borehole);
    }

    /// Fully updates a borehole's infrastructure attributes.
    pub fn updateBoreholeFull(self: *DataStore, id: []const u8, name: []const u8, depth_m: f64, pump_type: PumpType, yield_lph: u32, implemented_date: []const u8) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.boreholes.items) |*b| {
            if (std.mem.eql(u8, b.id, id)) {
                b.name = try self.allocator.dupe(u8, name);
                b.depth_m = depth_m;
                b.pump_type = pump_type;
                b.yield_lph = yield_lph;
                b.implemented_date = try self.allocator.dupe(u8, implemented_date);
                return true;
            }
        }
        return false;
    }

    /// Partially updates a borehole's status and dashboard visibility.
    pub fn patchBorehole(self: *DataStore, id: []const u8, status: ?BoreholeStatus, is_visible: ?bool) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.boreholes.items) |*b| {
            if (std.mem.eql(u8, b.id, id)) {
                if (status) |s| b.status = s;
                if (is_visible) |v| b.is_visible = v;
                return true;
            }
        }
        return false;
    }

    /// Deletes a borehole record by ID.
    pub fn deleteBorehole(self: *DataStore, id: []const u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        for (self.boreholes.items, 0..) |b, i| {
            if (std.mem.eql(u8, b.id, id)) {
                _ = self.boreholes.swapRemove(i);
                return true;
            }
        }
        return false;
    }
};
