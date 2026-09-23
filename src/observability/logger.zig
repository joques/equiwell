const std = @import("std");

/// Structured application logger supporting standardized JSON-like output.
pub const Logger = struct {
    pub const Level = enum {
        debug,
        info,
        warn,
        err,

        pub fn toString(self: Level) []const u8 {
            return switch (self) {
                .debug => "DEBUG",
                .info => "INFO",
                .warn => "WARN",
                .err => "ERROR",
            };
        }
    };

    min_level: Level = .info,

    pub fn init(min_level: Level) Logger {
        return .{ .min_level = min_level };
    }

    pub fn logRequest(self: Logger, request_id: []const u8, method: []const u8, path: []const u8, status_code: u16, duration_ms: i64) void {
        _ = self;
        std.debug.print("[HTTP] request_id={s} method={s} path={s} status={d} duration={d}ms\n", .{
            request_id, method, path, status_code, duration_ms
        });
    }

    pub fn info(self: Logger, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.min_level) <= @intFromEnum(Level.info)) {
            std.debug.print("[INFO] " ++ fmt ++ "\n", args);
        }
    }

    pub fn warn(self: Logger, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(self.min_level) <= @intFromEnum(Level.warn)) {
            std.debug.print("[WARN] " ++ fmt ++ "\n", args);
        }
    }

    pub fn err(self: Logger, comptime fmt: []const u8, args: anytype) void {
        _ = self;
        std.debug.print("[ERROR] " ++ fmt ++ "\n", args);
    }
};

pub const default_logger: Logger = .{};
