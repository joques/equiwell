const std = @import("std");
const AllocationRepository = @import("../repositories/allocation_repository.zig").AllocationRepository;
const AllocationMetric = @import("../models/allocation.zig").AllocationMetric;

pub const AllocationService = struct {
    repo: AllocationRepository,

    pub fn init(repo: AllocationRepository) AllocationService {
        return .{ .repo = repo };
    }

    pub fn getAllocationMetrics(self: AllocationService) AllocationMetric {
        return self.repo.getMetrics();
    }
};
