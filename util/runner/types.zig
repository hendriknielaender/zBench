const std = @import("std");

pub const Error = std.mem.Allocator.Error;

pub const Step = enum { more };

pub const Reading = struct {
    timing_ns: u64,

    pub fn init(timing_ns: u64) Reading {
        return .{
            .timing_ns = timing_ns,
        };
    }
};

pub const Readings = struct {
    timings_ns: []u64,
};
