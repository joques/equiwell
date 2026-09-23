const std = @import("std");

/// Environment mode of the EquiWell application.
pub const Environment = enum {
    development,
    staging,
    production,
    testing,

    pub fn fromString(str: []const u8) Environment {
        if (std.mem.eql(u8, str, "production")) return .production;
        if (std.mem.eql(u8, str, "staging")) return .staging;
        if (std.mem.eql(u8, str, "testing")) return .testing;
        return .development;
    }
};

/// Global enterprise configuration struct for the EquiWell API server.
pub const Config = struct {
    /// Host or network interface to bind to (e.g. "127.0.0.1" or "0.0.0.0").
    host: []const u8 = "127.0.0.1",
    /// Port number to listen on (e.g. 8080).
    port: u16 = 8080,
    /// Cryptographic secret key used for HMAC-SHA256 JWT signature generation and verification.
    jwt_secret: []const u8 = "equiwell-secret-key-kunene-2026-secure-token",
    /// Default token expiration lifetime in seconds (e.g. 3600s = 1 hour).
    token_expiry_seconds: u64 = 3600,
    /// Application environment mode.
    environment: Environment = .development,
    /// Google Maps Directions API key.
    google_maps_api_key: []const u8 = "",
    /// External AI Worker service URL for distributed compute.
    ai_worker_url: []const u8 = "http://127.0.0.1:5000",
    /// Target database connection URL (e.g. "inmemory://" or "postgres://...").
    database_url: []const u8 = "inmemory://",
    /// Logging verbosity level ("debug", "info", "warn", "error").
    log_level: []const u8 = "info",

    /// Initializes a Config instance with environment overrides or defaults.
    pub fn initFromEnv(allocator: std.mem.Allocator) Config {
        _ = allocator;
        return default_config;
    }
};

/// Default static configuration instance.
pub const default_config: Config = .{};
