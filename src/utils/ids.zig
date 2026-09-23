const std = @import("std");

/// Standardized entity ID format generators.
pub const Ids = struct {
    pub fn formatUserId(allocator: std.mem.Allocator, index: usize) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "USR-{0d:0>3}", .{index});
    }

    pub fn formatBoreholeId(allocator: std.mem.Allocator, index: usize) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "BH-{0d:0>4}", .{1000 + index});
    }

    pub fn formatLabTestId(allocator: std.mem.Allocator, index: usize) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "LAB-2026-{0d:0>3}", .{index});
    }

    pub fn formatTelemetryId(allocator: std.mem.Allocator, index: usize) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "TEL-{0d:0>5}", .{index});
    }

    pub fn formatCommunityRequestId(allocator: std.mem.Allocator, index: usize) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "COM-REQ-{0d:0>3}", .{100 + index});
    }

    pub fn formatSuggestionId(allocator: std.mem.Allocator, index: usize) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "SUG-{0d:0>4}", .{1000 + index});
    }

    pub fn formatDrillingLogId(allocator: std.mem.Allocator, index: usize) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "DLOG-{0d:0>5}", .{index});
    }

    pub fn formatTaskId(allocator: std.mem.Allocator, index: usize) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "TASK-AI-{0d:0>4}", .{7700 + index});
    }
};
