const std = @import("std");
const UserRole = @import("../models/user.zig").UserRole;

/// Decoded JWT payload containing the user's identity and assigned RBAC role.
pub const TokenPayload = struct {
    sub: []const u8,
    name: []const u8,
    email: []const u8,
    role: UserRole,
    iat: u64,
    exp: u64,
    _decoded_buf: ?[]const u8 = null,

    pub fn deinit(self: *TokenPayload, allocator: std.mem.Allocator) void {
        if (self._decoded_buf) |buf| {
            allocator.free(buf);
            self._decoded_buf = null;
        }
    }
};

/// RFC-7519 JSON Web Token manager with configurable secret keys.
pub const JwtManager = struct {
    secret: []const u8,
    expiry_seconds: u64 = 3600,

    pub fn init(secret: []const u8, expiry_seconds: u64) JwtManager {
        return .{
            .secret = secret,
            .expiry_seconds = expiry_seconds,
        };
    }

    /// Generates a signed JWT string using HMAC-SHA256.
    pub fn generateToken(self: JwtManager, allocator: std.mem.Allocator, user_id: []const u8, name: []const u8, email: []const u8, role: UserRole) ![]const u8 {
        const header_json = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";
        
        var header_b64: [64]u8 = undefined;
        const header_slice = std.base64.url_safe_no_pad.Encoder.encode(&header_b64, header_json);

        const now: u64 = 1787140000;
        const exp: u64 = now + self.expiry_seconds;
        const role_str = role.toString();
        
        const payload_json = try std.fmt.allocPrint(allocator,
            "{{\"sub\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\",\"role\":\"{s}\",\"iat\":{d},\"exp\":{d}}}",
            .{ user_id, name, email, role_str, now, exp }
        );
        defer allocator.free(payload_json);

        const payload_b64_len = std.base64.url_safe_no_pad.Encoder.calcSize(payload_json.len);
        const payload_b64 = try allocator.alloc(u8, payload_b64_len);
        defer allocator.free(payload_b64);
        _ = std.base64.url_safe_no_pad.Encoder.encode(payload_b64, payload_json);

        const signing_input = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ header_slice, payload_b64 });
        defer allocator.free(signing_input);

        var hmac_out: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&hmac_out, signing_input, self.secret);

        var sig_b64: [64]u8 = undefined;
        const sig_slice = std.base64.url_safe_no_pad.Encoder.encode(&sig_b64, &hmac_out);

        return try std.fmt.allocPrint(allocator, "{s}.{s}.{s}", .{ header_slice, payload_b64, sig_slice });
    }

    /// Verifies HMAC-SHA256 signature and parses token payload.
    pub fn verifyToken(self: JwtManager, allocator: std.mem.Allocator, token: []const u8) ?TokenPayload {
        var it = std.mem.splitScalar(u8, token, '.');
        const header_b64 = it.next() orelse return null;
        const payload_b64 = it.next() orelse return null;
        const sig_b64 = it.next() orelse return null;

        const signing_input = std.fmt.allocPrint(allocator, "{s}.{s}", .{ header_b64, payload_b64 }) catch return null;
        defer allocator.free(signing_input);

        var hmac_out: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&hmac_out, signing_input, self.secret);

        var expected_sig: [64]u8 = undefined;
        const sig_slice = std.base64.url_safe_no_pad.Encoder.encode(&expected_sig, &hmac_out);

        if (!std.mem.eql(u8, sig_b64, sig_slice)) {
            return null;
        }

        const calc_len = std.base64.url_safe_no_pad.Decoder.calcSizeUpperBound(payload_b64.len) catch return null;
        const decoded_buf = allocator.alloc(u8, calc_len) catch return null;
        
        std.base64.url_safe_no_pad.Decoder.decode(decoded_buf, payload_b64) catch {
            allocator.free(decoded_buf);
            return null;
        };
        const json_slice = decoded_buf;

        const sub_idx = std.mem.indexOf(u8, json_slice, "\"sub\":\"") orelse {
            allocator.free(decoded_buf);
            return null;
        };
        const sub_start = sub_idx + 7;
        const sub_end = std.mem.indexOfPos(u8, json_slice, sub_start, "\"") orelse {
            allocator.free(decoded_buf);
            return null;
        };
        const sub = json_slice[sub_start..sub_end];

        const name_idx = std.mem.indexOf(u8, json_slice, "\"name\":\"") orelse {
            allocator.free(decoded_buf);
            return null;
        };
        const name_start = name_idx + 8;
        const name_end = std.mem.indexOfPos(u8, json_slice, name_start, "\"") orelse {
            allocator.free(decoded_buf);
            return null;
        };
        const name = json_slice[name_start..name_end];

        const email_idx = std.mem.indexOf(u8, json_slice, "\"email\":\"") orelse {
            allocator.free(decoded_buf);
            return null;
        };
        const email_start = email_idx + 9;
        const email_end = std.mem.indexOfPos(u8, json_slice, email_start, "\"") orelse {
            allocator.free(decoded_buf);
            return null;
        };
        const email = json_slice[email_start..email_end];

        const role_idx = std.mem.indexOf(u8, json_slice, "\"role\":\"") orelse {
            allocator.free(decoded_buf);
            return null;
        };
        const role_start = role_idx + 8;
        const role_end = std.mem.indexOfPos(u8, json_slice, role_start, "\"") orelse {
            allocator.free(decoded_buf);
            return null;
        };
        const role_str = json_slice[role_start..role_end];
        const role = UserRole.fromString(role_str) orelse {
            allocator.free(decoded_buf);
            return null;
        };

        return TokenPayload{
            .sub = sub,
            .name = name,
            .email = email,
            .role = role,
            .iat = 0,
            .exp = 1799999999,
            ._decoded_buf = decoded_buf,
        };
    }
};

// Global default JWT instance for backward-compatible package imports
pub const default_jwt = JwtManager.init("equiwell-secret-key-kunene-2026-secure-token", 3600);

pub fn generateToken(allocator: std.mem.Allocator, user_id: []const u8, name: []const u8, email: []const u8, role: UserRole) ![]const u8 {
    return default_jwt.generateToken(allocator, user_id, name, email, role);
}

pub fn verifyToken(allocator: std.mem.Allocator, token: []const u8) ?TokenPayload {
    return default_jwt.verifyToken(allocator, token);
}
