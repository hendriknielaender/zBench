const std = @import("std");
const Runner = @import("runner.zig");
const TrackingAllocator = @import("allocators/tracking_allocator.zig");
const ShufflingAllocator = @import("allocators/shuffling_allocator.zig").ShufflingAllocator;

/// Hooks containing optional hooks for lifecycle events in benchmarking.
/// Each field in this struct is a nullable function pointer.
pub const Hooks = struct {
    before_all: ?*const fn () void = null,
    after_all: ?*const fn () void = null,
    before_each: ?*const fn () void = null,
    after_each: ?*const fn () void = null,
};

/// Configuration for benchmarking.
/// This struct holds settings to control the behavior of benchmark executions.
pub const Config = struct {
    /// Number of iterations for a given benchmark.
    /// The default is 0, meaning 'determined automatically'.
    /// Provide a specific number to override automatic determination.
    iterations: u32 = 0,

    /// Maximum number of iterations the benchmark should run.
    /// A custom value for .iterations will override this property.
    max_iterations: u32 = Runner.DEFAULT_MAX_N_ITER,

    /// Time budget for the benchmark in nanoseconds.
    /// This value is used to determine how long a benchmark run should take.
    time_budget_ns: u64 = Runner.DEFAULT_TIME_BUDGET_NS,

    /// Configuration for lifecycle hooks in benchmarking.
    /// Provides the ability to define custom actions at different stages of the benchmark process:
    /// - `before_all`: A hook that runs once before all benchmarks begin.
    /// - `after_all`: A hook that runs once after all benchmarks have completed.
    /// - `before_each`: A hook that runs before each individual benchmark.
    /// - `after_each`: A hook that runs after each individual benchmark.
    /// This allows for custom setup and teardown operations, as well as fine-grained control
    /// over the environment in which benchmarks are run.
    hooks: Hooks = .{},

    /// Track memory allocations made using the Allocator provided to
    /// benchmarks.
    track_allocations: bool = false,

    /// Use the ShufflingAllocator if true (experimental).
    /// This can be combined with track_allocations to wrap
    /// the shuffling allocator in a tracking allocator.
    use_shuffling_allocator: bool = false,
};

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
