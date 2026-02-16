const std = @import("std");
const expectEq = std.testing.expectEqual;
const expectEqSlices = std.testing.expectEqualSlices;

pub const Error = @import("types.zig").Error;
pub const Step = @import("types.zig").Step;
pub const AllocationReading = @import("types.zig").AllocationReading;
pub const AllocationReadings = @import("types.zig").AllocationReadings;
pub const Reading = @import("types.zig").Reading;
pub const Readings = @import("types.zig").Readings;

const Runner = @This();

pub const DEFAULT_MAX_N_ITER = 100_000;
pub const DEFAULT_TIME_BUDGET_NS = 2_000_000_000;

const State = union(enum) {
    preparing: Preparing,
    running: Running,

    const Preparing = struct {
        /// Number of iterations to be performed in the benchmark.
        N: usize = 1,

        /// Maximum number of iterations the benchmark can run. This limit helps
        /// to avoid excessively long benchmark runs.
        max_iterations: u32,

        /// Time budget for the benchmark in nanoseconds. This value is used to
        /// determine how long a single benchmark should be allowed to run
        /// before concluding. Helps in avoiding long-running benchmarks.
        time_budget_ns: u64,

        /// How many more test runs to do before doubling N.
        iterations_remaining: usize = 1,

        /// Time spent measuring the test's running time while calibrating,
        /// calibration stops if it reaches time_budget_ns.
        elapsed_ns: u64 = 0,

        /// Number of countdowns done from increasing values of N, calibration
        /// stops if it reaches max_iterations.
        iteration_loops: usize = 0,
    };

    const Running = struct {
        /// Total number of iterations done.
        iterations_count: usize,

        /// Number of timings still to be performed in the benchmark.
        iterations_remaining: usize,

        /// Readings collected during the run.
        readings: Readings,
    };
};

allocator: std.mem.Allocator,
track_allocations: bool,
state: State,

pub fn init(
    allocator: std.mem.Allocator,
    iterations: u32,
    max_iterations: u32,
    time_budget_ns: u64,
    track_allocations: bool,
) Error!Runner {
    return if (iterations == 0) .{
        .allocator = allocator,
        .track_allocations = track_allocations,
        .state = .{ .preparing = .{
            .max_iterations = max_iterations,
            .time_budget_ns = time_budget_ns,
        } },
    } else .{
        .allocator = allocator,
        .track_allocations = track_allocations,
        .state = .{ .running = .{
            .iterations_count = iterations,
            .iterations_remaining = iterations,
            .readings = try Readings.init(
                allocator,
                iterations,
                track_allocations,
            ),
        } },
    };
}

pub fn next(self: *Runner, reading: Reading) Error!?Step {
    switch (self.state) {
        .preparing => |*st| {
            st.elapsed_ns += reading.timing_ns;
            st.iteration_loops += 1;
            if (st.elapsed_ns >= st.time_budget_ns or st.iteration_loops >= st.max_iterations) {
                // Safety first: make sure the recorded durations aren't all-zero
                if (st.elapsed_ns == 0) st.elapsed_ns = 1;
                // Adjust N based on the actual duration achieved
                var N: usize = @intCast((st.iteration_loops * st.time_budget_ns) / st.elapsed_ns);
                // check that N doesn't go out of bounds
                if (N == 0) N = 1;
                if (N > st.max_iterations) N = st.max_iterations; // defaults to DEFAULT_MAX_N_ITER
                // Now run the benchmark with the adjusted N value
                self.state = .{ .running = .{
                    .iterations_count = N,
                    .iterations_remaining = N,
                    .readings = try Readings.init(
                        self.allocator,
                        N,
                        self.track_allocations,
                    ),
                } };
            }
            return .more;
        },
        .running => |*st| {
            if (st.iterations_remaining > 0) {
                const i = st.readings.iterations - st.iterations_remaining;
                st.readings.set(i, reading);
                st.iterations_remaining -= 1;
            }
            return if (st.iterations_remaining == 0) null else .more;
        },
    }
}

/// The next() function has returned null and there are no more steps to
/// complete, so get the timing results.
pub fn finish(self: *Runner) Error!Readings {
    return switch (self.state) {
        .preparing => Readings{
            .allocator = self.allocator,
            .iterations = 0,
            .timings_ns = &.{},
            .allocations = null,
        },
        .running => |st| st.readings,
    };
}

/// Clean up after an error.
pub fn abort(self: *Runner) void {
    return switch (self.state) {
        .preparing => {},
        .running => |st| st.readings.deinit(),
    };
}

pub const Status = struct {
    total_runs: usize,
    completed_runs: usize,
};

pub fn status(self: Runner) Status {
    return switch (self.state) {
        .preparing => Status{
            .total_runs = 0,
            .completed_runs = 0,
        },
        .running => |st| Status{
            .total_runs = st.iterations_count,
            .completed_runs = st.iterations_count - st.iterations_remaining,
        },
    };
}

test "runner, time budget limited" {
    var r = try Runner.init(std.testing.allocator, 0, DEFAULT_MAX_N_ITER, DEFAULT_TIME_BUDGET_NS, false);
    {
        errdefer r.abort();
        // run 10 steps spin-up, time budget is depleted => N is 10, but max_iterations aren't reached.
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            try expectEq(Step.more, try r.next(Reading.init(DEFAULT_TIME_BUDGET_NS / 10, null)));
        }

        // 9 runs yield .more as the next step
        try expectEq(Step.more, try r.next(Reading.init(100_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(100_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(100_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(200_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(300_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(400_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(100_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(200_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(300_000_000, null)));
        // number 10 is the final step
        try expectEq(@as(?Step, null), try r.next(Reading.init(400_000_000, null)));
    }
    const result = try r.finish();
    defer result.deinit();

    try expectEqSlices(u64, &.{
        100_000_000, 100_000_000, 100_000_000, 200_000_000, 300_000_000, 400_000_000,
        100_000_000, 200_000_000, 300_000_000, 400_000_000,
    }, result.timings_ns);
}

test "runner, max n runs limited" {
    var r = try Runner.init(std.testing.allocator, 0, 10, DEFAULT_TIME_BUDGET_NS, false);
    {
        errdefer r.abort();
        // spin-up: each run takes just one ns so that the max_iterations setting kicks in
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            try expectEq(Step.more, try r.next(Reading.init(1, null)));
        }

        // same as for the time budget: 9 runs yield .more as the next step:
        try expectEq(Step.more, try r.next(Reading.init(100_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(100_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(100_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(200_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(300_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(400_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(100_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(200_000_000, null)));
        try expectEq(Step.more, try r.next(Reading.init(300_000_000, null)));
        // number 10 is the final step:
        try expectEq(@as(?Step, null), try r.next(Reading.init(400_000_000, null)));
    }
    const result = try r.finish();
    defer result.deinit();
}

test "Runner - memory tracking" {
    var r = try Runner.init(std.testing.allocator, 0, 16384, 2e9, true);
    {
        errdefer r.abort();
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            try expectEq(Step.more, try r.next(Reading.init((DEFAULT_TIME_BUDGET_NS / 10), null)));
        }

        try expectEq(Step.more, try r.next(Reading.init(100, .{ .max = 1, .count = 2 })));
        try expectEq(Step.more, try r.next(Reading.init(200, .{ .max = 2, .count = 4 })));
        try expectEq(Step.more, try r.next(Reading.init(300, .{ .max = 4, .count = 8 })));
        try expectEq(Step.more, try r.next(Reading.init(400, .{ .max = 8, .count = 16 })));
        try expectEq(Step.more, try r.next(Reading.init(100, .{ .max = 16, .count = 32 })));
        try expectEq(Step.more, try r.next(Reading.init(200, .{ .max = 32, .count = 64 })));
        try expectEq(Step.more, try r.next(Reading.init(300, .{ .max = 64, .count = 128 })));
        try expectEq(Step.more, try r.next(Reading.init(400, .{ .max = 128, .count = 256 })));
        try expectEq(Step.more, try r.next(Reading.init(100, .{ .max = 256, .count = 512 })));
        try expectEq(@as(?Step, null), try r.next(Reading.init(200, .{ .max = 512, .count = 1024 })));
    }
    const result = try r.finish();
    defer result.deinit();
    try expectEqSlices(u64, &.{
        100, 200, 300, 400, 100, 200, 300, 400, 100, 200,
    }, result.timings_ns);
    try expectEqSlices(
        usize,
        &.{ 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 },
        result.allocations.?.maxes,
    );
    try expectEqSlices(
        usize,
        &.{ 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 },
        result.allocations.?.counts,
    );
}
