const std = @import("std");
const Config = @import("config.zig").Config;
const Runner = @import("runner.zig");
const TrackingAllocator = @import("tracking_allocator.zig");
const ShufflingAllocator = @import("shuffling_allocator.zig").ShufflingAllocator;

/// A function pointer type that represents a benchmark function.
pub const BenchFunc = *const fn (std.mem.Allocator) void;

/// A function pointer type that represents a parameterised benchmark function.
pub const ParameterisedFunc = *const fn (*const anyopaque, std.mem.Allocator) void;

/// A benchmark definition.
pub const Definition = struct {
    name: []const u8,
    config: Config,
    defn: union(enum) {
        simple: BenchFunc,
        parameterised: struct {
            func: ParameterisedFunc,
            context: *const anyopaque,
        },
    },

    /// Run and time a benchmark function once, as well as running before and
    /// after hooks.
    pub fn run(self: Definition, allocator: std.mem.Allocator) !Runner.Reading {
        if (self.config.use_shuffling_allocator) {
            var shuffle_allocator = ShufflingAllocator.create(allocator, 0);
            defer shuffle_allocator.deinit();

            if (self.config.track_allocations) {
                var tracking_allocator = TrackingAllocator.init(shuffle_allocator.allocator());
                return self.runImpl(tracking_allocator.allocator(), &tracking_allocator);
            } else {
                return self.runImpl(shuffle_allocator.allocator(), null);
            }
        } else if (self.config.track_allocations) {
            var tracking_allocator = TrackingAllocator.init(allocator);
            return self.runImpl(tracking_allocator.allocator(), &tracking_allocator);
        }

        return self.runImpl(allocator, null);
    }

    fn runImpl(
        self: Definition,
        allocator: std.mem.Allocator,
        tracking: ?*TrackingAllocator,
    ) !Runner.Reading {
        if (self.config.hooks.before_each) |hook| hook();
        defer if (self.config.hooks.after_each) |hook| hook();

        var t = try std.time.Timer.start();
        switch (self.defn) {
            .simple => |func| func(allocator),
            .parameterised => |x| x.func(@ptrCast(x.context), allocator),
        }
        return Runner.Reading{
            .timing_ns = t.read(),
            .allocation = if (tracking) |trk| Runner.AllocationReading{
                .max = trk.maxAllocated(),
                .count = trk.allocationCount(),
            } else null,
        };
    }
};
