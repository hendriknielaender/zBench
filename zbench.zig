//!zig-autodoc-guide: docs/intro.md
//!zig-autodoc-guide: docs/quickstart.md
//!zig-autodoc-guide: docs/advanced.md

const std = @import("std");
const expectEq = std.testing.expectEqual;

const Color = @import("./util/color.zig").Color;
const format = @import("./util/format.zig");
const Optional = @import("./util/optional.zig").Optional;
const optional = @import("./util/optional.zig").optional;
const platform = @import("./util/platform.zig");
const runner = @import("./util/runner.zig");

/// Hooks containing optional hooks for lifecycle events in benchmarking.
/// Each field in this struct is a nullable function pointer.
const Hooks = struct {
    before_all: ?*const fn () void = null,
    after_all: ?*const fn () void = null,
    before_each: ?*const fn () void = null,
    after_each: ?*const fn () void = null,
};

/// Configuration for benchmarking.
/// This struct holds settings to control the behavior of benchmark executions.
pub const Config = struct {
    /// Number of iterations the benchmark has been run. Initialized to 0.
    /// If 0 then zBench will calculate an value.
    iterations: u16 = 0,

    /// Maximum number of iterations the benchmark can run. Default is 16384.
    /// This limit helps to avoid excessively long benchmark runs.
    max_iterations: u16 = 16384,

    /// Time budget for the benchmark in nanoseconds. Default is 2e9 (2 seconds).
    /// This value is used to determine how long a single benchmark should be allowed to run
    /// before concluding. Helps in avoiding long-running benchmarks.
    time_budget_ns: u64 = 2e9,

    /// Configuration for lifecycle hooks in benchmarking.
    /// Provides the ability to define custom actions at different stages of the benchmark process:
    /// - `before_all`: A hook that runs once before all benchmarks begin.
    /// - `after_all`: A hook that runs once after all benchmarks have completed.
    /// - `before_each`: A hook that runs before each individual benchmark.
    /// - `after_each`: A hook that runs after each individual benchmark.
    /// This allows for custom setup and teardown operations, as well as fine-grained control
    /// over the environment in which benchmarks are run.
    hooks: Hooks = .{},
};

/// A benchmark definition.
const Definition = struct {
    name: []const u8,
    func: BenchFunc,
    config: Config,
};

/// A function pointer type that represents a benchmark function.
pub const BenchFunc = *const fn (std.mem.Allocator) void;

/// Benchmark manager, add your benchmark functions and run measure them.
pub const Benchmark = struct {
    allocator: std.mem.Allocator,
    common_config: Config,
    benchmarks: std.ArrayListUnmanaged(Definition) = .{},

    pub fn init(allocator: std.mem.Allocator, config: Config) Benchmark {
        return Benchmark{
            .allocator = allocator,
            .common_config = config,
        };
    }

    pub fn deinit(self: *Benchmark) void {
        self.benchmarks.deinit(self.allocator);
    }

    /// Add a benchmark function to be timed with `run()`.
    pub fn add(
        self: *Benchmark,
        name: []const u8,
        func: BenchFunc,
        config: Optional(Config),
    ) !void {
        try self.benchmarks.append(self.allocator, Definition{
            .name = name,
            .func = func,
            .config = optional(Config, config, self.common_config),
        });
    }

    /// Run all benchmarks and collect timing information.
    pub fn run(self: Benchmark) !Results {
        const n_benchmarks = self.benchmarks.items.len;
        const results = try self.allocator.alloc(Result, n_benchmarks);
        for (self.benchmarks.items, results) |b, *result| {
            if (b.config.hooks.before_all) |hook| hook();
            defer if (b.config.hooks.after_all) |hook| hook();

            var r = try runner.init(
                self.allocator,
                b.config.iterations,
                b.config.max_iterations,
                b.config.time_budget_ns,
            );
            errdefer r.abort();
            while (try r.next(try self.runFunc(b))) |_| {}
            result.* = try Result.init(self.allocator, b.name, try r.finish());
        }
        return Results{ .allocator = self.allocator, .results = results };
    }

    /// Run and time a benchmark function once, as well as running before and
    /// after hooks.
    fn runFunc(self: Benchmark, defn: Definition) !u64 {
        if (defn.config.hooks.before_each) |hook| hook();
        defer if (defn.config.hooks.after_each) |hook| hook();

        var t = try std.time.Timer.start();
        defn.func(self.allocator);
        return t.read();
    }

    /// Write the prettyPrint() header to a writer.
    pub fn prettyPrintHeader(_: Benchmark, writer: anytype) !void {
        try format.prettyPrintHeader(writer);
    }

    /// Get a copy of the system information, cpu type, cores, memory, etc.
    pub fn getSystemInfo(_: Benchmark) !platform.OsInfo {
        return try platform.getSystemInfo();
    }
};

/// A collection of the results of each benchmark. The results are available in
/// the `results` array but they can be collectively pretty printed and
/// deallocated with this structure.
pub const Results = struct {
    allocator: std.mem.Allocator,
    results: []Result,

    pub fn deinit(self: Results) void {
        for (self.results) |r| r.deinit();
        self.allocator.free(self.results);
    }

    /// Formats and prints the benchmark results in a human readable format.
    /// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
    /// colors: Whether to pretty-print with ANSI colors or not.
    pub fn prettyPrint(self: Results, writer: anytype, colors: bool) !void {
        try format.prettyPrintHeader(writer);
        for (self.results) |r| try r.prettyPrint(writer, colors);
    }

    /// Prints a summary output at the end of benchmarking sessions
    /// This summary highlights the fastest benchmark by name in green, and compares each
    /// subsequent benchmark to show how many times slower they are relative to the fastest.
    pub fn printSummary(self: Results, writer: anytype) !void {
        if (self.results.len == 0) return;

        const bold = Color.bold.code();
        const resetCode = Color.reset.code();
        const greenCode = Color.green.code();
        const blueCode = Color.blue.code();

        // Find the fastest result without sorting
        var fastestIndex: usize = 0;
        var fastestTime = self.results[0].statistics.mean_ns;
        for (self.results, 0..) |res, i| {
            if (res.statistics.mean_ns < fastestTime) {
                fastestTime = res.statistics.mean_ns;
                fastestIndex = i;
            }
        }

        // Print Summary Heading in Bold
        try writer.print("\n \n{s}Summary{s}\n", .{ bold, resetCode });

        try writer.print("{s}", .{greenCode});
        try writer.print("{s}", .{self.results[fastestIndex].name});
        try writer.print("{s} ran\n", .{resetCode});

        for (self.results, 0..) |res, i| {
            if (i == fastestIndex) continue; // Skip the fastest since it's already printed
            const times = @as(f64, @floatFromInt(res.statistics.mean_ns)) / @as(f64, @floatFromInt(fastestTime));

            try writer.print(" └─ {s}{d:.2}x times{s} faster than {s}{s}\n", .{ greenCode, times, resetCode, blueCode, res.name });
            try writer.print("{s}", .{resetCode});
        }
    }

    /// Prints the benchmark results in a machine readable JSON format.
    pub fn writeJSON(self: Results, writer: anytype) !void {
        try writer.writeAll("{\"benchmarks\": [\n");
        for (self.results, 0..) |r, i| {
            if (i != 0) try writer.writeAll(", ");
            try r.writeJSON(writer);
        }
        try writer.writeAll("]}\n");
    }
};

/// Carries the results of a benchmark. The benchmark name and the recorded
/// durations are available, and some basic statistics are automatically
/// calculated. The timings can always be assumed to be sorted.
pub const Result = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    timings_ns: []const u64,

    // Statistics stored behind a pointer so Results can be cheap to pass by
    // value.
    statistics: *const Statistics,

    const Statistics = struct {
        total_ns: u64,
        mean_ns: u64,
        stddev_ns: u64,
        min_ns: u64,
        max_ns: u64,
        percentiles: Percentiles,
    };

    const Percentiles = struct {
        p75_ns: u64,
        p99_ns: u64,
        p995_ns: u64,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        timings_ns: []u64,
    ) !Result {
        const len = timings_ns.len;
        std.sort.heap(u64, timings_ns, {}, std.sort.asc(u64));

        // Calculate total and mean runtime
        var total_ns: u64 = 0;
        for (timings_ns) |ns| total_ns += ns;
        const mean_ns: u64 = if (0 < len) total_ns / len else 0;

        // Calculate standard deviation
        const stddev_ns: u64 = blk: {
            var nvar: u64 = 0;
            for (timings_ns) |ns| {
                const sd = if (ns < mean_ns) mean_ns - ns else ns - mean_ns;
                nvar += sd * sd;
            }
            break :blk if (1 < len) std.math.sqrt(nvar / (len - 1)) else 0;
        };

        const statistics: *Statistics = try allocator.create(Statistics);
        statistics.* = Statistics{
            .total_ns = total_ns,
            .mean_ns = mean_ns,
            .stddev_ns = stddev_ns,
            .min_ns = if (len == 0) 0 else timings_ns[0],
            .max_ns = if (len == 0) 0 else timings_ns[len - 1],
            .percentiles = Percentiles{
                .p75_ns = if (len == 0) 0 else timings_ns[len * 75 / 100],
                .p99_ns = if (len == 0) 0 else timings_ns[len * 99 / 100],
                .p995_ns = if (len == 0) 0 else timings_ns[len * 995 / 1000],
            },
        };

        return Result{
            .allocator = allocator,
            .name = name,
            .statistics = statistics,
            .timings_ns = timings_ns,
        };
    }

    pub fn deinit(self: Result) void {
        self.allocator.free(self.timings_ns);
        self.allocator.destroy(self.statistics);
    }

    /// Formats and prints the benchmark result in a human readable format.
    /// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
    /// colors: Whether to pretty-print with ANSI colors or not.
    pub fn prettyPrint(self: Result, writer: anytype, colors: bool) !void {
        const s = self.statistics;
        const p = s.percentiles;
        try format.prettyPrintName(self.name, writer);
        try setColor(colors, writer, Color.cyan);
        try format.prettyPrintTotalOperations(self.timings_ns.len, writer);
        try format.prettyPrintTotalTime(s.total_ns, writer);
        try setColor(colors, writer, Color.green);
        try format.prettyPrintAvgStd(s.mean_ns, s.stddev_ns, writer);
        try setColor(colors, writer, Color.blue);
        try format.prettyPrintMinMax(s.min_ns, s.max_ns, writer);
        try setColor(colors, writer, Color.cyan);
        try format.prettyPrintPercentiles(p.p75_ns, p.p99_ns, p.p995_ns, writer);
        try setColor(colors, writer, Color.reset);
        try writer.writeAll("\n");
    }

    fn setColor(colors: bool, writer: anytype, color: Color) !void {
        if (colors) try writer.writeAll(color.code());
    }

    pub fn writeJSON(self: Result, writer: anytype) !void {
        const s = self.statistics;
        const p = s.percentiles;
        try std.fmt.format(
            writer,
            \\{{ "name": "{s}",
            \\   "units": "nanoseconds",
            \\   "total": {d},
            \\   "mean": {d},
            \\   "stddev": {d},
            \\   "min": {d},
            \\   "max": {d},
            \\   "percentiles": {{"p75": {d}, "p99": {d}, "p995": {d} }},
            \\   "timings": [
        ,
            .{
                std.fmt.fmtSliceEscapeLower(self.name),
                s.total_ns,
                s.mean_ns,
                s.stddev_ns,
                s.min_ns,
                s.max_ns,
                p.p75_ns,
                p.p99_ns,
                p.p995_ns,
            },
        );
        for (self.timings_ns, 0..) |ns, i| {
            if (0 < i) try writer.writeAll(", ");
            try std.fmt.format(writer, "{d}", .{ns});
        }
        try writer.writeAll("]}");
    }
};

test "Result" {
    {
        var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
        const r = try Result.init(std.testing.allocator, "r", try timings_ns.toOwnedSlice());
        defer r.deinit();
        try expectEq(@as(u64, 0), r.statistics.mean_ns);
        try expectEq(@as(u64, 0), r.statistics.stddev_ns);
    }

    {
        var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
        try timings_ns.append(1);
        const r = try Result.init(std.testing.allocator, "r", try timings_ns.toOwnedSlice());
        defer r.deinit();
        try expectEq(@as(u64, 1), r.statistics.mean_ns);
        try expectEq(@as(u64, 0), r.statistics.stddev_ns);
    }

    {
        var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
        try timings_ns.append(1);
        for (1..16) |i| try timings_ns.append(i);
        const r = try Result.init(std.testing.allocator, "r", try timings_ns.toOwnedSlice());
        defer r.deinit();
        try expectEq(@as(u64, 7), r.statistics.mean_ns);
        try expectEq(@as(u64, 4), r.statistics.stddev_ns);
    }

    {
        var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
        try timings_ns.append(1);
        for (1..101) |i| try timings_ns.append(i);
        const r = try Result.init(std.testing.allocator, "r", try timings_ns.toOwnedSlice());
        defer r.deinit();
        try expectEq(@as(u64, 50), r.statistics.mean_ns);
        try expectEq(@as(u64, 29), r.statistics.stddev_ns);
    }

    {
        var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
        for (0..10) |_| try timings_ns.append(1);
        const r = try Result.init(std.testing.allocator, "r", try timings_ns.toOwnedSlice());
        defer r.deinit();
        try expectEq(@as(u64, 1), r.statistics.mean_ns);
        try expectEq(@as(u64, 0), r.statistics.stddev_ns);
    }

    {
        var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
        for (0..100) |i| try timings_ns.append(i);
        const r = try Result.init(std.testing.allocator, "r", try timings_ns.toOwnedSlice());
        defer r.deinit();
        try expectEq(@as(u64, 75), r.statistics.percentiles.p75_ns);
        try expectEq(@as(u64, 99), r.statistics.percentiles.p99_ns);
        try expectEq(@as(u64, 99), r.statistics.percentiles.p995_ns);
    }

    {
        var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
        for (0..100) |i| try timings_ns.append(i);
        std.mem.reverse(u64, timings_ns.items);
        const r = try Result.init(std.testing.allocator, "r", try timings_ns.toOwnedSlice());
        defer r.deinit();
        try expectEq(@as(u64, 75), r.statistics.percentiles.p75_ns);
        try expectEq(@as(u64, 99), r.statistics.percentiles.p99_ns);
        try expectEq(@as(u64, 99), r.statistics.percentiles.p995_ns);
    }
}
