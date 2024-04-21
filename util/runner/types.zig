const std = @import("std");

pub const Error = std.mem.Allocator.Error;

pub const Step = enum { more };

pub const Reading = struct {
    timing_ns: u64,
    allocation: ?AllocationReading,

    pub fn init(
        timing_ns: u64,
        allocation: ?AllocationReading,
    ) Reading {
        return .{
            .timing_ns = timing_ns,
            .allocation = allocation,
        };
    }
};

pub const Readings = struct {
    allocator: std.mem.Allocator,
    iterations: usize,
    timings_ns: []u64,
    allocations: ?AllocationReadings,

    pub fn init(
        allocator: std.mem.Allocator,
        n: usize,
        track_allocations: bool,
    ) !Readings {
        return Readings{
            .allocator = allocator,
            .iterations = n,
            .timings_ns = try allocator.alloc(u64, n),
            .allocations = if (track_allocations)
                try AllocationReadings.init(allocator, n)
            else
                null,
        };
    }

    pub fn deinit(self: Readings) void {
        self.allocator.free(self.timings_ns);
        if (self.allocations) |allocs| allocs.deinit(self.allocator);
    }

    pub fn set(self: *Readings, i: usize, reading: Reading) void {
        self.timings_ns[i] = reading.timing_ns;
        if (self.allocations) |allocs| {
            if (reading.allocation) |x| {
                allocs.maxes[i] = x.max;
                allocs.counts[i] = x.count;
            } else {
                allocs.deinit(self.allocator);
                self.allocations = null;
            }
        }
    }
};

pub const AllocationReading = struct {
    max: usize,
    count: usize,
};

pub const AllocationReadings = struct {
    maxes: []usize,
    counts: []usize,

    pub fn init(allocator: std.mem.Allocator, n: usize) !AllocationReadings {
        return AllocationReadings{
            .maxes = try allocator.alloc(usize, n),
            .counts = try allocator.alloc(usize, n),
        };
    }

    pub fn deinit(self: AllocationReadings, allocator: std.mem.Allocator) void {
        allocator.free(self.maxes);
        allocator.free(self.counts);
    }
};
