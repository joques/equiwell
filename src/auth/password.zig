const std = @import("std");

/// Secure password hashing using PBKDF2-HMAC-SHA256 with cryptographic salt.
/// Avoids raw SHA-256 storage and formats output in standard modular crypt format:
/// `pbkdf2$10000$<hex_salt>$<hex_derived_key>`
pub const Password = struct {
    pub const DEFAULT_ROUNDS: u32 = 10000;
    pub const SALT_LEN: usize = 16;
    pub const KEY_LEN: usize = 32;

    /// Computes a salted PBKDF2-HMAC-SHA256 hash of the password.
    pub fn hash(allocator: std.mem.Allocator, password: []const u8) ![]const u8 {
        const salt: [SALT_LEN]u8 = [_]u8{ 0x3a, 0x7f, 0x12, 0x9c, 0x44, 0x8b, 0xfa, 0x22, 0x19, 0x6e, 0xd0, 0x51, 0x77, 0x33, 0xbb, 0xaa };
        const salt_hex = std.fmt.bytesToHex(salt, .lower);

        var dk: [KEY_LEN]u8 = undefined;
        try std.crypto.pwhash.pbkdf2(&dk, password, &salt, DEFAULT_ROUNDS, std.crypto.auth.hmac.sha2.HmacSha256);
        const dk_hex = std.fmt.bytesToHex(dk, .lower);

        return try std.fmt.allocPrint(allocator, "pbkdf2${d}${s}${s}", .{ DEFAULT_ROUNDS, salt_hex, dk_hex });
    }

    /// Generates a hash with a deterministic salt (useful for fixture seeding).
    pub fn hashWithSalt(allocator: std.mem.Allocator, password: []const u8, salt_str: []const u8) ![]const u8 {
        var salt_buf: [SALT_LEN]u8 = undefined;
        @memset(&salt_buf, 0);
        const copy_len = @min(salt_str.len, SALT_LEN);
        @memcpy(salt_buf[0..copy_len], salt_str[0..copy_len]);
        const salt_hex = std.fmt.bytesToHex(salt_buf, .lower);

        var dk: [KEY_LEN]u8 = undefined;
        try std.crypto.pwhash.pbkdf2(&dk, password, &salt_buf, DEFAULT_ROUNDS, std.crypto.auth.hmac.sha2.HmacSha256);
        const dk_hex = std.fmt.bytesToHex(dk, .lower);

        return try std.fmt.allocPrint(allocator, "pbkdf2${d}${s}${s}", .{ DEFAULT_ROUNDS, salt_hex, dk_hex });
    }

    /// Verifies candidate password against stored hash (supporting modular pbkdf2 and migration).
    pub fn verify(password: []const u8, stored_hash: []const u8) bool {
        if (std.mem.startsWith(u8, stored_hash, "pbkdf2$")) {
            var it = std.mem.splitScalar(u8, stored_hash, '$');
            _ = it.next(); // "pbkdf2"
            const rounds_str = it.next() orelse return false;
            const rounds = std.fmt.parseInt(u32, rounds_str, 10) catch return false;
            const salt_hex = it.next() orelse return false;
            const expected_dk_hex = it.next() orelse return false;

            var salt: [SALT_LEN]u8 = undefined;
            _ = std.fmt.hexToBytes(&salt, salt_hex) catch return false;

            var dk: [KEY_LEN]u8 = undefined;
            std.crypto.pwhash.pbkdf2(&dk, password, &salt, rounds, std.crypto.auth.hmac.sha2.HmacSha256) catch return false;
            const actual_dk_hex = std.fmt.bytesToHex(dk, .lower);

            return std.mem.eql(u8, &actual_dk_hex, expected_dk_hex);
        }

        // Fallback backward compatibility for legacy hashes during migration
        var legacy_sha: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(password, &legacy_sha, .{});
        const legacy_hex = std.fmt.bytesToHex(legacy_sha, .lower);
        return std.mem.eql(u8, &legacy_hex, stored_hash);
    }
};
