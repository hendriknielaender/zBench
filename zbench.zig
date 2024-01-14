//!zig-autodoc-guide: docs/intro.md
//!zig-autodoc-guide: docs/quickstart.md
//!zig-autodoc-guide: docs/advanced.md

const std = @import("std");
const log = std.log.scoped(.zbench);

const c = @import("./util/color.zig");
const format = @import("./util/format.zig");

/// Benchmark is a type containing state for a single benchmark session.
/// It provides metrics and utilities for performance measurement.
pub const Benchmark = struct {
    pub const Percentiles = struct {
        p75: u64,
        p99: u64,
        p995: u64,
    };

    pub const RunArgs = struct {
        /// Name of the benchmark
        name: []const u8 = "benchmark",
        /// Maximum runs (or iterations) benchmark-runner should perform
        max_runs: u64 = 65536,
        /// Maximum time (in nanoseconds) we are willing to wait for the benchmark-runner
        max_time: u64 = 2_000_000_000,
        /// Allocator to be used by the benchmark-runner. If null then
        /// the same allocator from the `Benchmark` instance is used instead
        alloc: ?std.mem.Allocator = null,
    };

    /// Divisor used to decide the number of trial runs to perform
    pub const TRIAL_RUN_DIV: u64 = 32;

    /// Number of runs (or iterations) to be performed in the benchmark.
    N: usize = 1,
    /// Timer used to track the duration of the benchmark.
    timer: std.time.Timer,
    /// Total number of benchmark runs (or iterations) that have been performed
    total_runs: usize = 0,
    /// Minimum duration recorded among all runs (initially set to the maximum possible value).
    min_duration: u64 = std.math.maxInt(u64),
    /// Maximum duration recorded among all runs.
    max_duration: u64 = 0,
    /// Total duration accumulated over all runs.
    total_duration: u64 = 0,
    /// A dynamic list storing the duration of each run.
    durations: std.ArrayList(u64),
    /// Memory allocator used by the benchmark.
    allocator: std.mem.Allocator,

    /// Initializes a new Benchmark instance.
    /// allocator: Memory allocator to be used.
    pub fn init(allocator: std.mem.Allocator) !Benchmark {
        const bench = Benchmark{
            .allocator = allocator,
            .timer = std.time.Timer.start() catch return error.TimerUnsupported,
            .durations = std.ArrayList(u64).init(allocator),
        };
        return bench;
    }

    /// Executes a benchmark-runner within the context of a given Benchmark object. Note
    /// that this function calls `Benchmark.reset` at the start, and so all contained
    /// state is discarded and replaced.
    ///
    /// benchResult: A pointer to BenchmarkResults to store the results.
    /// run_args: Various parameters for the benchmark
    /// Runner: The benchmark-runner. Must be one of either -
    ///     Standalone function with *either* of the following signature/function type -
    ///         1: fn (std.mem.Allocator) void          : Required
    ///         2: fn (*zbench.Benchmark) void          : Required
    ///
    ///     Aggregate (Struct/Union/Enum) with following associated methods -
    ///         pub fn init(std.mem.Allocator) !Self    : Required
    ///         pub fn run(Self) void                   : Required
    ///         pub fn deinit(Self) void                : Optional
    ///         pub fn reset(Self) void                 : Optional
    ///
    /// NOTE:
    ///     The function signatures must match or non-sensical compilation-errors may ensue
    ///
    ///     `*Self` instead of `Self` also works for the above methods.
    ///
    ///     If `reset` is not supplied, the runner instance is "deinited" and
    ///     "inited" between every run (which may slowdown your benchmark-suite).
    pub fn run(self: *Benchmark, comptime Runner: anytype, bench_results: *BenchmarkResults, run_args: RunArgs) !void {
        try bench_results.results.append(try self.runSingle(Runner, run_args));
    }

    /// Similar to `Benchmark.run`, but this function can be used when we
    /// aren't interested in gathering a large collection of results and so
    /// returns the BenchmarkResult directly
    pub fn runSingle(self: *Benchmark, comptime Runner: anytype, run_args: RunArgs) !BenchmarkResult {
        self.reset();
        const err_msg = "Benchmark.run: `Runner` must be an aggregate (Enum, Union or Struct), or a function.\nIf a function, it must have the signature `fn (std.mem.Allocator) void` or `fn (*zbench.Benchmark) void`";

        comptime var has_init: bool = false;
        comptime var has_run: bool = false;
        comptime var has_reset: bool = false;
        comptime var has_deinit: bool = false;
        var run_arg = if (@TypeOf(Runner) == type) b: { // We hit this branch when `Runner` is an aggregate
            const err_msg_aggregate = "Benchmark.run: `Runner` did not have both `run` and `init` as associated methods";

            const decls = switch (@typeInfo(Runner)) {
                .Struct => |agr| agr.decls,
                .Union => |agr| agr.decls,
                .Enum => |agr| agr.decls,

                else => @compileError(err_msg),
            };

            comptime for (decls) |dec| {
                if (std.mem.eql(u8, dec.name, "reset")) {
                    has_reset = true;
                } else if (std.mem.eql(u8, dec.name, "deinit")) {
                    has_deinit = true;
                } else if (std.mem.eql(u8, dec.name, "init")) {
                    has_init = true;
                } else if (std.mem.eql(u8, dec.name, "run")) {
                    has_run = true;
                }
            };

            comptime if (has_init == false or has_run == false)
                @compileError(err_msg_aggregate);

            break :b try Runner.init(self.allocator);
        } else b: { // We hit this branch when `Runner` is a standalone function
            if (@TypeOf(Runner) == fn (std.mem.Allocator) void) {
                if (run_args.alloc) |a| break :b a else break :b self.allocator;
            } else if (@TypeOf(Runner) == fn (*Benchmark) void)
                break :b self
            else
                @compileError(err_msg);
        };

        // First we do some trial runs to warm up the system and get a time-estimate
        // of how long each benchmar-run will take including init/deinit or reset
        // The idea is to do a fraction of the total number of runs, hence division by
        // `TRIAL_RUN_DIV`
        const trial_runs = @max(run_args.max_runs / TRIAL_RUN_DIV, 10);
        const trial_time = @max(run_args.max_time / TRIAL_RUN_DIV, 10_000);
        while (self.total_duration < trial_time and self.total_runs < trial_runs) {
            // All of these branches evaluate at compile-time!
            self.start();
            if (has_init) run_arg.run() else Runner(run_arg);

            self.total_runs += 1;

            if (has_reset) {
                run_arg.reset();
                continue;
            } else if (has_deinit)
                run_arg.deinit();
            if (has_init) run_arg = try Runner.init(self.allocator);
            self.stop();
        }

        // Make an estimate for the number of runs to be performed. Here we take the smallest of
        // max_runner_time / avg_runner_time and max_runner_runs.
        self.N = @min(run_args.max_time / (self.calculateAverage() + 1), run_args.max_runs);

        // Now that we have obtained a reasonable value for the number of iterations
        // we can perform the actual benchmark-runs
        self.reset();
        for (0..self.N) |_| {
            self.start();
            if (has_init) run_arg.run() else Runner(run_arg);
            self.stop();

            if (has_reset) {
                run_arg.reset();
                continue;
            } else if (has_deinit)
                run_arg.deinit();
            if (has_init) run_arg = try Runner.init(self.allocator);
        }
        self.setTotalRuns(self.N);

        if (has_deinit) run_arg.deinit();

        const ret = BenchmarkResult{
            .name = run_args.name,
            .percs = self.calculatePercentiles(),
            .avg_duration = self.calculateAverage(),
            .std_duration = self.calculateStd(),
            .min_duration = self.min_duration,
            .max_duration = self.max_duration,
            .total_runs = self.total_runs,
            .total_time = self.elapsed(),
        };

        return ret;
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
        self.total_runs = 0;
        self.min_duration = std.math.maxInt(u64);
        self.max_duration = 0;
        self.total_duration = 0;
        self.durations.clearRetainingCapacity();
    }

    /// Returns the elapsed time since the benchmark started.
    pub fn elapsed(self: *Benchmark) u64 {
        var sum: u64 = 0;
        for (self.durations.items) |duration| {
            sum += duration;
        }
        return sum;
    }

    /// Sets the total number of runs performed.
    /// ops: Number of runs.
    pub fn setTotalRuns(self: *Benchmark, ops: usize) void {
        self.total_runs = ops;
    }

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
            log.debug("Cannot calculate percentiles: recorded less than two durations", .{});
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

    // NOTE: Decide if this function should be removed as this is just
    // a duplicate of `BenchmarkResult.prettyPrint`
    /// Prints a report of total operations and timing statistics.
    /// (Similar to BenchmarkResult.prettyPrint)
    pub fn report(self: Benchmark) !void {
        const percentiles = self.calculatePercentiles();

        var total_time_buffer: [128]u8 = undefined;
        const total_time_str = try format.duration(total_time_buffer[0..], self.elapsed());

        var p75_buffer: [128]u8 = undefined;
        const p75_str = try format.duration(p75_buffer[0..], percentiles.p75);

        var p99_buffer: [128]u8 = undefined;
        const p99_str = try format.duration(p99_buffer[0..], percentiles.p99);

        var p995_buffer: [128]u8 = undefined;
        const p995_str = try format.duration(p995_buffer[0..], percentiles.p995);

        var avg_std_buffer: [128]u8 = undefined;
        var avg_std_offset = (try format.duration(avg_std_buffer[0..], self.calculateAverage())).len;
        avg_std_offset += (try std.fmt.bufPrint(avg_std_buffer[avg_std_offset..], " ± ", .{})).len;
        avg_std_offset += (try format.duration(avg_std_buffer[avg_std_offset..], self.calculateStd())).len;
        const avg_std_str = avg_std_buffer[0..avg_std_offset];

        var min_buffer: [128]u8 = undefined;
        const min_str = try format.duration(min_buffer[0..], self.min_duration);

        var max_buffer: [128]u8 = undefined;
        const max_str = try format.duration(max_buffer[0..], self.max_duration);

        var min_max_buffer: [128]u8 = undefined;
        const min_max_str = try std.fmt.bufPrint(min_max_buffer[0..], "({s} ... {s})", .{ min_str, max_str });

        const stdout = std.io.getStdOut().writer();
        prettyPrintHeader();
        try stdout.print("---------------------------------------------------------------------------------------------------------------\n", .{});
        try stdout.print(
            "{s:<22} \x1b[90m{d:<8} \x1b[90m{s:<10} \x1b[33m{s:<22} \x1b[95m{s:<28} \x1b[90m{s:<10} {s:<10} {s:<10}\x1b[0m\n\n",
            .{ self.name, self.total_runs, total_time_str, avg_std_str, min_max_str, p75_str, p99_str, p995_str },
        );
        try stdout.print("\n", .{});
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

    /// Calculate the standard deviation of the durations
    pub fn calculateStd(self: Benchmark) u64 {
        if (self.durations.items.len <= 1) return 0;

        const avg = self.calculateAverage();
        var nvar: u64 = 0;
        for (self.durations.items) |dur| {
            // NOTE: With realistic real-life samples this will never overflow,
            // however a solution without bitcasts would still be cleaner
            const d: i64 = @bitCast(dur);
            const a: i64 = @bitCast(avg);

            nvar += @bitCast((d - a) * (d - a));
        }

        // We are using the non-biased estimator for the variance; sum(Xi - μ)^2 / (n - 1)
        return std.math.sqrt(nvar / (self.durations.items.len - 1));
    }
};

/// BenchmarkResult stores the resulting computed metrics/statistics from a benchmark
pub const BenchmarkResult = struct {
    name: []const u8,
    percs: Benchmark.Percentiles,
    avg_duration: usize,
    std_duration: usize,
    min_duration: usize,
    max_duration: usize,
    total_runs: usize,
    total_time: usize,

    /// Formats and prints the benchmark result in a readable format.
    pub fn prettyPrint(self: BenchmarkResult, header: bool) !void {
        var total_time_buffer: [128]u8 = undefined;
        const total_time_str = try format.duration(total_time_buffer[0..], self.total_time);

        var p75_buffer: [128]u8 = undefined;
        const p75_str = try format.duration(p75_buffer[0..], self.percs.p75);

        var p99_buffer: [128]u8 = undefined;
        const p99_str = try format.duration(p99_buffer[0..], self.percs.p99);

        var p995_buffer: [128]u8 = undefined;
        const p995_str = try format.duration(p995_buffer[0..], self.percs.p995);

        var avg_std_buffer: [128]u8 = undefined;
        var avg_std_offset = (try format.duration(avg_std_buffer[0..], self.avg_duration)).len;
        avg_std_offset += (try std.fmt.bufPrint(avg_std_buffer[avg_std_offset..], " ± ", .{})).len;
        avg_std_offset += (try format.duration(avg_std_buffer[avg_std_offset..], self.std_duration)).len;
        const avg_std_str = avg_std_buffer[0..avg_std_offset];

        var min_buffer: [128]u8 = undefined;
        const min_str = try format.duration(min_buffer[0..], self.min_duration);

        var max_buffer: [128]u8 = undefined;
        const max_str = try format.duration(max_buffer[0..], self.max_duration);

        var min_max_buffer: [128]u8 = undefined;
        const min_max_str = try std.fmt.bufPrint(min_max_buffer[0..], "({s} ... {s})", .{ min_str, max_str });

        if (header) try prettyPrintHeader();

        const stdout = std.io.getStdOut().writer();
        try stdout.print(
            "{s:<22} \x1b[90m{d:<8} \x1b[90m{s:<14} \x1b[33m{s:<22} \x1b[95m{s:<28} \x1b[90m{s:<10} {s:<10} {s:<10}\x1b[0m\n\n",
            .{ self.name, self.total_runs, total_time_str, avg_std_str, min_max_str, p75_str, p99_str, p995_str },
        );
    }
};

pub fn prettyPrintHeader() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        "\n{s:<22} {s:<8} {s:<14} {s:<22} {s:<28} {s:<10} {s:<10} {s:<10}\n",
        .{ "benchmark", "runs", "total time", "time/run (avg ± σ)", "(min ... max)", "p75", "p99", "p995" },
    );
    try stdout.print("-----------------------------------------------------------------------------------------------------------------------------\n", .{});
}

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
        try prettyPrintHeader();
        for (self.results.items) |result| {
            try result.prettyPrint(false);
        }
    }
};
