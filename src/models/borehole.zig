const std = @import("std");

/// Pump mechanism installed at a borehole asset.
pub const PumpType = enum {
    solar,
    diesel,
    hand_pump,
    hybrid,

    pub fn toString(self: PumpType) []const u8 {
        return switch (self) {
            .solar => "solar",
            .diesel => "diesel",
            .hand_pump => "hand_pump",
            .hybrid => "hybrid",
        };
    }

    pub fn fromString(str: []const u8) ?PumpType {
        if (std.mem.eql(u8, str, "solar")) return .solar;
        if (std.mem.eql(u8, str, "diesel")) return .diesel;
        if (std.mem.eql(u8, str, "hand_pump")) return .hand_pump;
        if (std.mem.eql(u8, str, "hybrid")) return .hybrid;
        return null;
    }
};

/// Operational health state of a borehole asset.
pub const BoreholeStatus = enum {
    working,
    broken,
    maintenance_required,

    pub fn toString(self: BoreholeStatus) []const u8 {
        return switch (self) {
            .working => "working",
            .broken => "broken",
            .maintenance_required => "maintenance_required",
        };
    }

    pub fn fromString(str: []const u8) ?BoreholeStatus {
        if (std.mem.eql(u8, str, "working")) return .working;
        if (std.mem.eql(u8, str, "broken")) return .broken;
        if (std.mem.eql(u8, str, "maintenance_required")) return .maintenance_required;
        return null;
    }
};

/// Physical groundwater asset record.
pub const Borehole = struct {
    id: []const u8,
    name: []const u8,
    lat: f64,
    lng: f64,
    depth_m: f64,
    pump_type: PumpType,
    yield_lph: u32,
    status: BoreholeStatus,
    water_quality: []const u8,
    implemented_date: []const u8,
    last_maintained: []const u8,
    is_visible: bool = true,
};
