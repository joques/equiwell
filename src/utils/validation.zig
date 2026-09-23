const std = @import("std");

/// Common input validation routines across EquiWell domain payloads.
pub const Validation = struct {
    /// Validates basic email address structure.
    pub fn isValidEmail(email: []const u8) bool {
        if (email.len < 5 or email.len > 254) return false;
        const at_pos = std.mem.indexOfScalar(u8, email, '@') orelse return false;
        if (at_pos == 0 or at_pos == email.len - 1) return false;
        const dot_pos = std.mem.indexOfScalarPos(u8, email, at_pos, '.') orelse return false;
        if (dot_pos == at_pos + 1 or dot_pos == email.len - 1) return false;
        return true;
    }

    /// Validates password complexity (at least 8 characters).
    pub fn isValidPassword(password: []const u8) bool {
        return password.len >= 8;
    }

    /// Validates GPS coordinates range (lat: [-90, 90], lng: [-180, 180]).
    pub fn isValidCoordinates(lat: f64, lng: f64) bool {
        return (lat >= -90.0 and lat <= 90.0 and lng >= -180.0 and lng <= 180.0);
    }
};
