const std = @import("std");
const Runner = @import("runner.zig");

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
