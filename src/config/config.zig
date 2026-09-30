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
    /// Hard limit on maximum allowed HTTP request body size in bytes (10MB default).
    max_body_size: usize = 10 * 1024 * 1024,
    /// Socket read and write timeout in milliseconds (5000ms default to mitigate Slowloris).
    socket_timeout_ms: u32 = 5000,
    /// Configurable Allowed Origins for CORS headers.
    cors_allowed_origins: []const u8 = "*",
    /// Number of concurrent worker threads in the bounded connection pool.
    worker_pool_size: usize = 16,

extern "kernel32" fn GetEnvironmentVariableA(lpName: [*:0]const u8, lpBuffer: [*]u8, nSize: u32) callconv(std.builtin.CallingConvention.winapi) u32;

fn getEnv(allocator: std.mem.Allocator, name: [*:0]const u8) ?[]const u8 {
    var buf: [512]u8 = undefined;
    const len = GetEnvironmentVariableA(name, &buf, buf.len);
    if (len > 0 and len < buf.len) {
        return allocator.dupe(u8, buf[0..len]) catch null;
    }
    return null;
}

    /// Initializes a Config instance with environment overrides or defaults.
    pub fn initFromEnv(allocator: std.mem.Allocator) Config {
        var cfg = default_config;

        if (getEnv(allocator, "HOST")) |v| {
            cfg.host = v;
        }
        if (getEnv(allocator, "PORT")) |v| {
            if (std.fmt.parseInt(u16, v, 10)) |p| {
                cfg.port = p;
            } else |_| {}
        }
        if (getEnv(allocator, "JWT_SECRET")) |v| {
            cfg.jwt_secret = v;
        }
        if (getEnv(allocator, "ENVIRONMENT")) |v| {
            cfg.environment = Environment.fromString(v);
        }
        if (getEnv(allocator, "DATABASE_URL")) |v| {
            cfg.database_url = v;
        }
        if (getEnv(allocator, "GOOGLE_MAPS_API_KEY")) |v| {
            cfg.google_maps_api_key = v;
        }
        if (getEnv(allocator, "AI_WORKER_URL")) |v| {
            cfg.ai_worker_url = v;
        }
        return cfg;
    }
};

/// Default static configuration instance.
pub const default_config: Config = .{};
