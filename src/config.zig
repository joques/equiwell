const std = @import("std");

/// Global runtime configuration structure for the EquiWell API server.
pub const Config = struct {
    /// Network hostname or IP interface to bind to (e.g. "127.0.0.1" for local loopback).
    host: []const u8 = "127.0.0.1",
    /// TCP port number to listen on (e.g. 8080).
    port: u16 = 8080,
    /// Cryptographic secret key used for HMAC-SHA256 JWT signature generation and verification.
    jwt_secret: []const u8 = "equiwell-secret-key-kunene-2026-secure-token",
    /// Default token expiration lifetime in seconds (e.g. 3600s = 1 hour).
    token_expiry_seconds: u64 = 3600,
};

/// Global singleton configuration instance used across the application.
pub const global_config: Config = .{};
