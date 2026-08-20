const std = @import("std");

/// Computes a secure SHA-256 cryptographic hash of the provided plaintext password.
///
/// Parameters:
///   - allocator: The memory allocator used to produce the returned hex string.
///   - password: The raw plaintext password string.
///
/// Returns:
///   A newly allocated slice containing the 64-character lowercase hexadecimal hash string.
pub fn hashPassword(allocator: std.mem.Allocator, password: []const u8) ![]const u8 {
    var hash_bytes: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(password, &hash_bytes, .{});
    const hex = std.fmt.bytesToHex(hash_bytes, .lower);
    return allocator.dupe(u8, &hex);
}

/// Verifies whether a candidate plaintext password matches a stored SHA-256 hash.
///
/// Parameters:
///   - password: The raw candidate password to verify.
///   - stored_hash: The 64-character lowercase hexadecimal hash string stored in the database.
///
/// Returns:
///   `true` if the hashed password matches the stored hash exactly, `false` otherwise.
pub fn verifyPassword(password: []const u8, stored_hash: []const u8) bool {
    var hash_bytes: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(password, &hash_bytes, .{});
    const hex = std.fmt.bytesToHex(hash_bytes, .lower);
    return std.mem.eql(u8, &hex, stored_hash);
}
