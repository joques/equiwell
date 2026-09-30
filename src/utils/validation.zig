const std = @import("std");

/// Common input validation routines across EquiWell domain payloads.
pub const Validation = struct {
    /// Checks if a floating point number is finite (not NaN, not Inf, not -Inf).
    pub fn isFiniteFloat(val: f64) bool {
        return !std.math.isNan(val) and !std.math.isInf(val);
    }

    /// Validates GPS coordinates range (lat: [-90, 90], lng: [-180, 180]) and finite values.
    pub fn isValidCoordinates(lat: f64, lng: f64) bool {
        if (!isFiniteFloat(lat) or !isFiniteFloat(lng)) return false;
        return (lat >= -90.0 and lat <= 90.0 and lng >= -180.0 and lng <= 180.0);
    }

    /// Validates email address structure and disallows control characters/spaces.
    pub fn isValidEmail(email: []const u8) bool {
        if (email.len < 5 or email.len > 254) return false;
        for (email) |c| {
            if (c <= 32 or c >= 127) return false;
        }
        // Disallow consecutive dots
        if (std.mem.indexOf(u8, email, "..") != null) return false;

        const at_pos = std.mem.indexOfScalar(u8, email, '@') orelse return false;
        if (at_pos == 0 or at_pos == email.len - 1) return false;

        // Disallow multiple '@' symbols
        if (std.mem.indexOfScalarPos(u8, email, at_pos + 1, '@') != null) return false;

        const dot_pos = std.mem.indexOfScalarPos(u8, email, at_pos, '.') orelse return false;
        if (dot_pos == at_pos + 1 or dot_pos == email.len - 1) return false;
        return true;
    }

    /// Validates password complexity (at least 8 characters, maximum 128 to prevent PBKDF2 DoS).
    pub fn isValidPassword(password: []const u8) bool {
        return password.len >= 8 and password.len <= 128;
    }

    /// Validates string length and non-emptiness after trimming whitespace.
    pub fn isValidString(str: []const u8, min_len: usize, max_len: usize) bool {
        const trimmed = std.mem.trim(u8, str, " \t\r\n");
        return trimmed.len >= min_len and str.len <= max_len;
    }

    /// Validates non-negative finite float within an upper bound [0.0, max_val].
    pub fn isValidPositiveFloat(val: f64, max_val: f64) bool {
        if (!isFiniteFloat(val)) return false;
        return val >= 0.0 and val <= max_val;
    }

    /// Validates strictly positive finite float within bounds (0.0, max_val].
    pub fn isValidStrictPositiveFloat(val: f64, max_val: f64) bool {
        if (!isFiniteFloat(val)) return false;
        return val > 0.0 and val <= max_val;
    }

    /// Validates percentage range [0, 100].
    pub fn isValidPercentage(val: u8) bool {
        return val <= 100;
    }

    /// Checks if a year is a Gregorian leap year.
    pub fn isLeapYear(year: u16) bool {
        return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
    }

    /// Returns the maximum days in a given month for a given year.
    pub fn maxDaysInMonth(year: u16, month: u8) u8 {
        return switch (month) {
            1, 3, 5, 7, 8, 10, 12 => 31,
            4, 6, 9, 11 => 30,
            2 => if (isLeapYear(year)) 29 else 28,
            else => 0,
        };
    }

    /// Validates ISO date format YYYY-MM-DD, range (1900..2100), and calendar validity (including leap years).
    pub fn isValidDate(str: []const u8) bool {
        if (str.len != 10) return false;
        if (str[4] != '-' or str[7] != '-') return false;

        for (str, 0..) |c, i| {
            if (i == 4 or i == 7) continue;
            if (c < '0' or c > '9') return false;
        }

        const year = std.fmt.parseInt(u16, str[0..4], 10) catch return false;
        const month = std.fmt.parseInt(u8, str[5..7], 10) catch return false;
        const day = std.fmt.parseInt(u8, str[8..10], 10) catch return false;

        if (year < 1900 or year > 2100) return false;
        if (month < 1 or month > 12) return false;

        const max_days = maxDaysInMonth(year, month);
        if (day < 1 or day > max_days) return false;

        return true;
    }

    /// Validates contact phone numbers (5..30 chars, allowed digits and punctuation).
    pub fn isValidPhone(phone: []const u8) bool {
        const trimmed = std.mem.trim(u8, phone, " \t\r\n");
        if (trimmed.len < 5 or phone.len > 30) return false;
        for (trimmed) |c| {
            if (!((c >= '0' and c <= '9') or c == '+' or c == '-' or c == ' ' or c == '(' or c == ')' or c == '.')) {
                return false;
            }
        }
        return true;
    }

    /// Validates urgency classification level.
    pub fn isValidUrgency(urgency: []const u8) bool {
        return std.mem.eql(u8, urgency, "low") or
            std.mem.eql(u8, urgency, "medium") or
            std.mem.eql(u8, urgency, "high") or
            std.mem.eql(u8, urgency, "critical");
    }
};
