const std = @import("std");

pub const Error = std.mem.Allocator.Error;

pub const Step = enum { more };

pub const Reading = struct {
    timing_ns: u64,
    max_allocated: ?usize,

    pub fn init(timing_ns: u64, max_allocated: ?usize) Reading {
        return .{
            .timing_ns = timing_ns,
            .max_allocated = max_allocated,
        };
    }
};

pub const Readings = struct {
    timings_ns: []u64,
    max_allocations: ?[]usize,
};
