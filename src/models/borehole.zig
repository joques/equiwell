const std = @import("std");

/// Primary energy and mechanical power source for a borehole pump.
pub const PumpType = enum {
    solar,
    diesel,
    hand_pump,
    hybrid,

    /// Converts the PumpType enum to its lowercase string representation.
    pub fn toString(self: PumpType) []const u8 {
        return switch (self) {
            .solar => "solar",
            .diesel => "diesel",
            .hand_pump => "hand_pump",
            .hybrid => "hybrid",
        };
    }

    /// Parses a string into a PumpType enum variant.
    pub fn fromString(str: []const u8) ?PumpType {
        if (std.mem.eql(u8, str, "solar")) return .solar;
        if (std.mem.eql(u8, str, "diesel")) return .diesel;
        if (std.mem.eql(u8, str, "hand_pump")) return .hand_pump;
        if (std.mem.eql(u8, str, "hybrid")) return .hybrid;
        return null;
    }
};

/// Operational health state of a borehole water asset.
pub const BoreholeStatus = enum {
    working,
    broken,
    maintenance_required,

    /// Converts BoreholeStatus to string.
    pub fn toString(self: BoreholeStatus) []const u8 {
        return switch (self) {
            .working => "working",
            .broken => "broken",
            .maintenance_required => "maintenance_required",
        };
    }

    /// Parses a string into BoreholeStatus.
    pub fn fromString(str: []const u8) ?BoreholeStatus {
        if (std.mem.eql(u8, str, "working")) return .working;
        if (std.mem.eql(u8, str, "broken")) return .broken;
        if (std.mem.eql(u8, str, "maintenance_required")) return .maintenance_required;
        return null;
    }
};

/// Core physical asset model representing a groundwater borehole in the Kunene Region.
pub const Borehole = struct {
    /// Unique borehole code (e.g. "BH-1002").
    id: []const u8,
    /// Descriptive name or village landmark (e.g. "Okangwati Community Well 1").
    name: []const u8,
    /// GPS latitude coordinate in decimal degrees.
    lat: f64,
    /// GPS longitude coordinate in decimal degrees.
    lng: f64,
    /// Total drilled depth in meters.
    depth_m: f64,
    /// Mechanical/energy pump mechanism.
    pump_type: PumpType,
    /// Tested water delivery yield in Liters per Hour (L/h).
    yield_lph: u32,
    /// Current operational state.
    status: BoreholeStatus,
    /// Water potability classification (e.g. "potable", "brackish", "untreated").
    water_quality: []const u8,
    /// Date when the borehole was officially commissioned/installed (e.g. "2024-03-15").
    implemented_date: []const u8,
    /// Date when preventative or corrective maintenance was last performed.
    last_maintained: []const u8,
    /// Whether the borehole is visible on the public dashboard map.
    is_visible: bool,
    /// Organization, installer, or entity responsible for drilling.
    installed_by: []const u8,
};
