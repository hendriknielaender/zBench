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
    ///         pub fn init(std.mem.Allocator) !Self    : Required
    ///         pub fn run(Self) void                   : Required
    ///         pub fn deinit(Self) void                : Optional
    ///         pub fn reset(Self) void                 : Optional
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
    ) !BenchmarkResult {
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

        const ret =  BenchmarkResult {
            .name = name,
            .percs = self.calculatePercentiles(),
            .avg_duration = self.calculateAverage(),
            .min_duration = self.min_duration,
            .max_duration = self.max_duration,
            .total_operations = self.total_operations,
        };

        self.reset();
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
            return Percentiles{ .p75 = 0, .p99 = 0, .p995 = 0 };
        }
        quickSort(self.durations.items, 0, lastIndex - 1);

        const p75Index: usize = len * 75 / 100;
        const p99Index: usize = len * 99 / 100;
        const p995Index: usize = len * 995 / 1000;

        const p75 = self.durations.items[p75Index];
        const p99 = self.durations.items[p99Index];
        const p995 = self.durations.items[p995Index];

        return Percentiles { .p75 = p75, .p99 = p99, .p995 = p995 };
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

pub const Percentiles = struct {
    p75: u64,
    p99: u64,
    p995: u64,
};

/// BenchFunc is a function type that represents a benchmark function.
/// It takes a pointer to a Benchmark object.
pub const BenchFunc = fn (*Benchmark) void;

/// BenchmarkResult stores the resulting computed metrics/statistics from a benchmark
pub const BenchmarkResult = struct {
    name: []const u8,
    percs: Percentiles,
    avg_duration: usize,
    min_duration: usize,
    max_duration: usize,
    total_operations: usize,

    pub fn prettyPrint(self: BenchmarkResult, header: bool) !void {
        var p75_buffer: [128]u8 = undefined;
        const p75_str = try format.duration(p75_buffer[0..], self.percs.p75);

        var p99_buffer: [128]u8 = undefined;
        const p99_str = try format.duration(p99_buffer[0..], self.percs.p99);

        var p995_buffer: [128]u8 = undefined;
        const p995_str = try format.duration(p995_buffer[0..], self.percs.p995);

        var avg_buffer: [128]u8 = undefined;
        const avg_str = try format.duration(avg_buffer[0..], self.avg_duration);

        var min_buffer: [128]u8 = undefined;
        const min_str = try format.duration(min_buffer[0..], self.min_duration);

        var max_buffer: [128]u8 = undefined;
        const max_str = try format.duration(max_buffer[0..], self.max_duration);

        if (header) prettyPrintHeader(); 
        std.debug.print("{s:<20} \x1b[33m{s:<12}\x1b[0m (\x1b[94m{s}\x1b[0m ... \x1b[95m{s}\x1b[0m)  \t\x1b[90m{s:<10}\x1b[0m \x1b[90m{s:<10}\x1b[0m \x1b[90m{s:<10} \x1b[90m{d}\x1b[0m\n", .{ self.name, avg_str, min_str, max_str, p75_str, p99_str, p995_str, self.total_operations });
    }
};

pub fn prettyPrintHeader() void {
    std.debug.print("{s:<20} {s:<12} {s}\t{s:<10} {s:<10} {s:<10} {s}\n", .{ "benchmark", "time (avg)", "(min ............. max)", "p75", "p99", "p995", "runs" });
    std.debug.print("-----------------------------------------------------------------------------------------------------\n", .{});
}

pub fn prettyPrintResults(results: []const BenchmarkResult, header: bool) !void {
    if (header) {
        prettyPrintHeader();
    }

    for (results) |res| try res.prettyPrint(false);
}
