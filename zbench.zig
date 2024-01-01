//!zig-autodoc-guide: docs/intro.md
//!zig-autodoc-guide: docs/quickstart.md
//!zig-autodoc-guide: docs/advanced.md

const std = @import("std");
const c = @import("./util/color.zig");
const format = @import("./util/format.zig");

/// Benchmark is a type representing a single benchmark session.
/// It provides metrics and utilities for performance measurement.
pub const Benchmark = struct {
    /// Timer used to track the duration of the benchmark.
    timer: std.time.Timer,
    /// Total number of operations performed during the benchmark.
    total_operations: usize = 0,
    /// Minimum duration recorded among all runs (initially set to the maximum possible value).
    min_duration: u64 = std.math.maxInt(u64),
    /// Maximum duration recorded among all runs.
    max_duration: u64 = 0,
    /// Maximum duration (approx) we are willing to wait for a benchmark
    max_duration_limit: u64,
    /// Maximum amount of runs to repeat for any given benchmark
    max_operations: u64,
    /// Total duration accumulated over all runs.
    total_duration: u64 = 0,
    /// A dynamic list storing the duration of each run.
    durations: std.ArrayList(u64),
    /// Memory allocator used by the benchmark.
    allocator: std.mem.Allocator,

    /// Initializes a new Benchmark instance.
    ///
    /// max_duration_limit: Max amount of time (in nanoseconds) we are willing
    /// to wait for any given invocation of `runBench`. Set this to a high number
    /// if you don't want time restrictions (ie. std.math.maxInt(u64)). NOTE: This
    /// is only an estimate and bench-runs may exceed the limit slightly.
    ///
    /// max_opererations: Maximum amount of benchmark-runs performed for any
    /// given invocation of `runBench`. This may be lower if the bench-time
    /// exceeds max_duration_estimate.
    ///
    /// allocator: Memory allocator to be used.
    pub fn init(
        max_duration_limit: u64,
        max_operations: u64,
        allocator: std.mem.Allocator,
    ) !Benchmark {
        const bench = Benchmark{
            .max_duration_limit = max_duration_limit,
            .max_operations = max_operations,
            .allocator = allocator,
            .timer = std.time.Timer.start() catch return error.TimerUnsupported,
            .durations = std.ArrayList(u64).init(allocator),
        };
        return bench;
    }

    /// Runner: Must be one of either -
    ///     Standalone function with following signature/function type -
    ///         fn (std.mem.Allocator) void         : Required
    ///
    ///     Aggregate (Struct/Union/Enum) with followin associated methods -
    ///         fn init(std.mem.Allocator) !Self    : Required
    ///         fn run(Self) void                   : Required
    ///         fn deinit(Self) void                : Optional
    ///         fn reset(Self) void                 : Optional
    ///
    /// NOTE: 
    ///     `*Self` instead of `Self` also works for the above types.
    ///
    ///     `reset` can be useful for increasing benchmarking speed. If it is
    ///     not supplied, the runner instance is "deinited" and "inited" between
    ///     every run.
    ///
    ///     If the above restrictions aren't matched exactly you may get strange
    ///     compilation errors that can be hard to debug!
    pub fn runBench(
        self: *Benchmark,
        comptime Runner: anytype,
        name: []const u8,
    ) !void {
        if (@TypeOf(Runner) == fn (std.mem.Allocator) void) {
            while (
                    self.total_duration < self.max_duration_limit
                and self.total_operations < self.max_operations
            ) {
                self.start();
                Runner(self.allocator);
                self.stop();

                self.total_operations += 1;
            }
        } else if (@TypeOf(Runner) == type) {
            const decls = switch (@typeInfo(Runner)) {
                .Struct =>  |agr| agr.decls,
                .Union =>   |agr| agr.decls,
                .Enum =>    |agr| agr.decls,

                else => @compileError("runBench: `Runner` must be an Enum, Union or Struct, or a standalone function")
            };

            comptime var has_reset = false;
            comptime var has_deinit = false;
            comptime for (decls) |dec| {
                if (std.mem.eql(u8, dec.name, "reset")) {
                    has_reset = true;
                } else if (std.mem.eql(u8, dec.name, "deinit")) {
                    has_deinit = true;
                }
            };

            var run_instance = try Runner.init(self.allocator);
            while (
                    self.total_duration < self.max_duration_limit
                and self.total_operations < self.max_operations
            ) {
                self.start();
                run_instance.run();
                self.stop();

                self.total_operations += 1;

                if (has_reset) {
                    run_instance.reset();
                    continue;
                } else if (has_deinit) {
                    run_instance.deinit();
                }

                run_instance = try Runner.init(self.allocator);
            }

            if (has_deinit) run_instance.deinit();
        } else {
            // Not sure if it's actually possible to hit this branch?
            @compileError("runBench: `Runner` must be an Enum, Union or Struct, or a standalone function with signature `fn (std.mem.Allocator) void`");
        }

        try self.prettyPrintResult(name);
        self.reset();
    }

    /// Starts or restarts the benchmark timer.
    pub fn start(self: *Benchmark) void {
        self.timer.reset();
    }

    /// Stop the benchmark and record the duration
    pub fn stop(self: *Benchmark) void {
        const elapsedDuration = self.timer.read();
        self.total_duration += elapsedDuration;

        if (elapsedDuration < self.min_duration) self.min_duration = elapsedDuration;
        if (elapsedDuration > self.max_duration) self.max_duration = elapsedDuration;

        self.durations.append(elapsedDuration) catch unreachable;
    }

    /// Reset the benchmark
    pub fn reset(self: *Benchmark) void {
        self.total_operations = 0;
        self.min_duration = 18446744073709551615;
        self.max_duration = 0;
        self.total_duration = 0;
        self.durations.deinit();
        self.durations = std.ArrayList(u64).init(self.allocator);
    }

    /// Returns the elapsed time since the benchmark started.
    pub fn elapsed(self: *Benchmark) u64 {
        var sum: u64 = 0;
        for (self.durations.items) |duration| {
            sum += duration;
        }
        return sum;
    }

    /// Sets the total number of operations performed.
    /// ops: Number of operations.
    pub fn setTotalOperations(self: *Benchmark, ops: usize) void {
        self.total_operations = ops;
    }

    /// Prints a report of total operations performed during the benchmark.
    pub fn report(self: *Benchmark) void {
        std.debug.print("Total operations: {}\n", .{self.total_operations});
    }

    pub const Percentiles = struct {
        p75: u64,
        p99: u64,
        p995: u64,
    };

    pub fn quickSort(items: []u64, low: usize, high: usize) void {
        if (low < high) {
            const pivotIndex = partition(items, low, high);
            if (pivotIndex != 0) {
                quickSort(items, low, pivotIndex - 1);
            }
            quickSort(items, pivotIndex + 1, high);
        }
    }

    fn partition(items: []u64, low: usize, high: usize) usize {
        const pivot = items[high];
        var i = low;

        var j = low;
        while (j <= high) : (j += 1) {
            if (items[j] < pivot) {
                std.mem.swap(u64, &items[i], &items[j]);
                i += 1;
            }
        }
        std.mem.swap(u64, &items[i], &items[high]);
        return i;
    }

    /// Calculate the p75, p99, and p995 durations
    pub fn calculatePercentiles(self: Benchmark) Percentiles {
        // quickSort might fail with an empty input slice, so safety checks first
        const len = self.durations.items.len;
        var lastIndex: usize = 0;
        if (len > 1) {
            lastIndex = len - 1;
        } else {
            std.debug.print("Cannot calculate percentiles: recorded less than two durations\n", .{});
            return Percentiles{ .p75 = 0, .p99 = 0, .p995 = 0 };
        }
        quickSort(self.durations.items, 0, lastIndex - 1);

        const p75Index: usize = len * 75 / 100;
        const p99Index: usize = len * 99 / 100;
        const p995Index: usize = len * 995 / 1000;

        const p75 = self.durations.items[p75Index];
        const p99 = self.durations.items[p99Index];
        const p995 = self.durations.items[p995Index];

        return Percentiles{ .p75 = p75, .p99 = p99, .p995 = p995 };
    }

    pub fn prettyPrintHeader() void {
        std.debug.print("{s:<20} {s:<12} {s}\t{s:<10} {s:<10} {s:<10} {s}\n", .{ "benchmark", "time (avg)", "(min ............. max)", "p75", "p99", "p995", "runs" });
        std.debug.print("-----------------------------------------------------------------------------------------------------\n", .{});
    }

    pub fn prettyPrintResult(self: Benchmark, name: []const u8) !void {
        const percentiles = self.calculatePercentiles();

        var p75_buffer: [128]u8 = undefined;
        const p75_str = try format.duration(p75_buffer[0..], percentiles.p75);

        var p99_buffer: [128]u8 = undefined;
        const p99_str = try format.duration(p99_buffer[0..], percentiles.p99);

        var p995_buffer: [128]u8 = undefined;
        const p995_str = try format.duration(p995_buffer[0..], percentiles.p995);

        var avg_buffer: [128]u8 = undefined;
        const avg_str = try format.duration(avg_buffer[0..], self.calculateAverage());

        var min_buffer: [128]u8 = undefined;
        const min_str = try format.duration(min_buffer[0..], self.min_duration);

        var max_buffer: [128]u8 = undefined;
        const max_str = try format.duration(max_buffer[0..], self.max_duration);

        std.debug.print("{s:<20} \x1b[33m{s:<12}\x1b[0m (\x1b[94m{s}\x1b[0m ... \x1b[95m{s}\x1b[0m)  \t\x1b[90m{s:<10}\x1b[0m \x1b[90m{s:<10}\x1b[0m \x1b[90m{s:<10} \x1b[90m{d}\x1b[0m\n", .{ name, avg_str, min_str, max_str, p75_str, p99_str, p995_str, self.total_operations });
    }

    /// Calculate the average duration
    pub fn calculateAverage(self: Benchmark) u64 {
        // prevent division by zero
        const len = self.durations.items.len;
        if (len == 0) return 0;

        var sum: u64 = 0;
        for (self.durations.items) |duration| {
            sum += duration;
        }

        const avg = sum / len;

        return avg;
    }

    pub fn deinit(self: Benchmark) void { self.durations.deinit(); }
};

/// BenchFunc is a function type that represents a benchmark function.
/// It takes a pointer to a Benchmark object.
pub const BenchFunc = fn (*Benchmark) void;

/// BenchmarkResult stores the result of a single benchmark.
/// It includes the name and the total duration of the benchmark.
pub const BenchmarkResult = struct {
    /// Name of the benchmark.
    name: []const u8,
    /// Total duration of the benchmark in nanoseconds.
    duration: u64,
};

/// BenchmarkResults acts as a container for multiple benchmark results.
/// It provides functionality to format and print these results.
pub const BenchmarkResults = struct {
    /// A dynamic list of BenchmarkResult objects.
    results: std.ArrayList(BenchmarkResult),

    /// Determines the color representation based on the duration of the benchmark.
    /// duration: The duration to evaluate.
    pub fn getColor(self: *const BenchmarkResults, duration: u64) c.Color {
        const max_duration = @max(self.results.items[0].duration, self.results.items[self.results.items.len - 1].duration);
        const min_duration = @min(self.results.items[0].duration, self.results.items[self.results.items.len - 1].duration);

        if (duration <= min_duration) return c.Color.green;
        if (duration >= max_duration) return c.Color.red;

        const prop = (duration - min_duration) * 100 / (max_duration - min_duration + 1);

        if (prop < 50) return c.Color.green;
        if (prop < 75) return c.Color.yellow;

        return c.Color.red;
    }

    /// Formats and prints the benchmark results in a readable format.
    pub fn prettyPrint(self: BenchmarkResults) !void {
        const stdout = std.io.getStdOut().writer();
        std.debug.print("--------------------------------------------------------------------------------------\n", .{});

        for (self.results.items) |result| {
            try stdout.print("{s}", .{result.name});
        }
    }
};

/// Executes a benchmark function within the context of a given Benchmark object.
/// func: The benchmark function to be executed.
/// bench: A pointer to a Benchmark object for tracking the benchmark.
/// benchResult: A pointer to BenchmarkResults to store the results.
pub fn run(comptime func: BenchFunc, bench: *Benchmark, benchResult: *BenchmarkResults) !void {
    defer bench.durations.deinit();
    const MIN_DURATION = 1_000_000_000; // minimum benchmark time in nanoseconds (1 second)
    const MAX_N = 65536; // maximum number of executions for the final benchmark run
    const MAX_ITERATIONS = 16384; // Define a maximum number of iterations

    bench.N = 1; // initial value; will be updated...
    var duration: u64 = 0;
    var iterations: usize = 0; // Add an iterations counter

    // increase N until we've run for a sufficiently long time or exceeded max_iterations
    while (duration < MIN_DURATION and iterations < MAX_ITERATIONS) {
        bench.reset();

        bench.start();
        var j: usize = 0;
        while (j < bench.N) : (j += 1) {
            func(bench);
        }

        bench.stop();
        // double N for next iteration
        if (bench.N < MAX_N / 2) {
            bench.N *= 2;
        } else {
            bench.N = MAX_N;
        }

        iterations += 1; // Increase the iteration counter
        duration += bench.elapsed(); // ...and duration
    }

    // Safety first: make sure the recorded durations aren't all-zero
    if (duration == 0) duration = 1;

    // Adjust N based on the actual duration achieved
    bench.N = @intCast((bench.N * MIN_DURATION) / duration);
    // check that N doesn't go out of bounds
    if (bench.N == 0) bench.N = 1;
    if (bench.N > MAX_N) bench.N = MAX_N;

    // Now run the benchmark with the adjusted N value
    bench.reset();
    var j: usize = 0;
    while (j < bench.N) : (j += 1) {
        bench.start();
        func(bench);
        bench.stop();
    }

    const elapsed = bench.elapsed();
    try benchResult.results.append(BenchmarkResult{
        .name = bench.name,
        .duration = elapsed,
    });

    bench.setTotalOperations(bench.N);
    bench.report();

    bench.prettyPrintHeader();
    try bench.prettyPrintResult();
}
