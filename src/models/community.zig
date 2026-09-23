const std = @import("std");

/// Formal water emergency intervention request submitted by traditional community leaders.
pub const CommunityRequest = struct {
    id: []const u8,
    community_name: []const u8,
    contact_person: []const u8,
    contact_phone: []const u8,
    issue: []const u8,
    urgency: []const u8,
    status: []const u8,
    submitted_at: []const u8,
};
