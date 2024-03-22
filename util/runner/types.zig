const std = @import("std");

pub const Error = std.mem.Allocator.Error;

pub const Step = enum { more };

pub const Reading = struct {
    timing_ns: u64,
    allocation_max: ?usize,
    allocation_count: ?usize,

    pub fn init(
        timing_ns: u64,
        allocation_max: ?usize,
        allocation_count: ?usize,
    ) Reading {
        return .{
            .timing_ns = timing_ns,
            .allocation_max = allocation_max,
            .allocation_count = allocation_count,
        };
    }
};

pub const Readings = struct {
    timings_ns: []u64,
    allocation_maxes: ?[]usize,
    allocation_counts: ?[]usize,
};
