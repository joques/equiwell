const std = @import("std");
const UserRole = @import("../models/user.zig").UserRole;
const config = @import("../config.zig");

/// Decoded JWT payload containing the user's identity and assigned RBAC role.
pub const TokenPayload = struct {
    /// Unique subject identifier (User ID, e.g. "USR-001").
    sub: []const u8,
    /// Full display name of the user.
    name: []const u8,
    /// Registered email address of the user.
    email: []const u8,
    /// Assigned Role-Based Access Control role enum.
    role: UserRole,
    /// Expiration timestamp in Unix epoch seconds.
    exp: u64,
    /// Internal reference to the allocated base64-decoded JSON buffer for memory cleanup.
    _decoded_buf: ?[]const u8 = null,

    /// Frees the internal decoded payload buffer allocated during token verification.
    pub fn deinit(self: *TokenPayload, allocator: std.mem.Allocator) void {
        if (self._decoded_buf) |buf| {
            allocator.free(buf);
            self._decoded_buf = null;
        }
    }
};

/// Generates a signed RFC-7519 JSON Web Token (JWT) using HMAC-SHA256.
///
/// Flow:
///   1. Encodes the standard JWT header `{"alg":"HS256","typ":"JWT"}` to Base64URL.
///   2. Serializes the user identity payload to JSON and encodes it to Base64URL.
///   3. Constructs the signing input: `header_b64.payload_b64`.
///   4. Computes the HMAC-SHA256 signature using the global server secret key.
///   5. Encodes the signature to Base64URL and concatenates: `header.payload.signature`.
///
/// Parameters:
///   - allocator: Allocator used to produce the returned token string.
///   - user_id: Unique user identifier string (e.g. "USR-001").
///   - name: Full user name.
///   - email: User email address.
///   - role: Assigned UserRole enum.
///
/// Returns:
///   A newly allocated JWT string (e.g. "eyJhbGciOi...").
pub fn generateToken(allocator: std.mem.Allocator, user_id: []const u8, name: []const u8, email: []const u8, role: UserRole) ![]const u8 {
    const header_json = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";
    
    // 1. Header Base64URL Encoding
    var header_b64: [64]u8 = undefined;
    const header_slice = std.base64.url_safe_no_pad.Encoder.encode(&header_b64, header_json);

    // 2. Payload JSON Serialization
    const exp: u64 = 1799999999;
    const role_str = role.toString();
    const payload_json = try std.fmt.allocPrint(allocator, "{{\"sub\":\"{s}\",\"name\":\"{s}\",\"email\":\"{s}\",\"role\":\"{s}\",\"exp\":{d}}}", .{
        user_id,
        name,
        email,
        role_str,
        exp,
    });
    defer allocator.free(payload_json);

    // 3. Payload Base64URL Encoding
    const payload_b64_len = std.base64.url_safe_no_pad.Encoder.calcSize(payload_json.len);
    const payload_b64 = try allocator.alloc(u8, payload_b64_len);
    defer allocator.free(payload_b64);
    _ = std.base64.url_safe_no_pad.Encoder.encode(payload_b64, payload_json);

    // 4. Signing Input Construction (Header.Payload)
    const signing_input = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ header_slice, payload_b64 });
    defer allocator.free(signing_input);

    // 5. Cryptographic Signature Generation (HMAC-SHA256)
    var hmac_out: [32]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha256.create(&hmac_out, signing_input, config.global_config.jwt_secret);

    // 6. Signature Base64URL Encoding
    var sig_b64: [64]u8 = undefined;
    const sig_slice = std.base64.url_safe_no_pad.Encoder.encode(&sig_b64, &hmac_out);

    // 7. Assemble Three-Part Token (Header.Payload.Signature)
    const token = try std.fmt.allocPrint(allocator, "{s}.{s}.{s}", .{ header_slice, payload_b64, sig_slice });
    return token;
}

/// Cryptographically verifies an incoming JWT Bearer token and extracts its payload.
///
/// Flow:
///   1. Splits the token into its three constituent parts: header, payload, and signature.
///   2. Recomputes the HMAC-SHA256 signature using the server's secret key and validates exact match.
///   3. Decodes the Base64URL payload into memory using the provided request allocator.
///   4. Parses the JSON fields (`sub`, `name`, `email`, `role`, `exp`) into a `TokenPayload` struct.
///
/// Parameters:
///   - allocator: The request-scoped allocator used to store the decoded string slices.
///   - token: The raw JWT string extracted from the HTTP Authorization header.
///
/// Returns:
///   A valid `TokenPayload` if the cryptographic signature and format are correct, or `null` if verification fails.
pub fn verifyToken(allocator: std.mem.Allocator, token: []const u8) ?TokenPayload {
    var it = std.mem.splitScalar(u8, token, '.');
    const header_b64 = it.next() orelse return null;
    const payload_b64 = it.next() orelse return null;
    const sig_b64 = it.next() orelse return null;

    // 1. Recompute and Verify HMAC-SHA256 Signature
    const signing_input = std.fmt.allocPrint(allocator, "{s}.{s}", .{ header_b64, payload_b64 }) catch return null;
    defer allocator.free(signing_input);

    var hmac_out: [32]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha256.create(&hmac_out, signing_input, config.global_config.jwt_secret);

    var expected_sig: [64]u8 = undefined;
    const sig_slice = std.base64.url_safe_no_pad.Encoder.encode(&expected_sig, &hmac_out);

    if (!std.mem.eql(u8, sig_b64, sig_slice)) {
        return null;
    }

    // 2. Decode Base64URL Payload into Request Allocator
    const calc_len = std.base64.url_safe_no_pad.Decoder.calcSizeUpperBound(payload_b64.len) catch return null;
    const decoded_buf = allocator.alloc(u8, calc_len) catch return null;
    
    std.base64.url_safe_no_pad.Decoder.decode(decoded_buf, payload_b64) catch {
        allocator.free(decoded_buf);
        return null;
    };
    const json_slice = decoded_buf;

    // 3. Extract JSON Fields
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
        .exp = 1799999999,
        ._decoded_buf = decoded_buf,
    };
}
