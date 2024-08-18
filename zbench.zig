//!zig-autodoc-guide: docs/intro.md
//!zig-autodoc-guide: docs/quickstart.md
//!zig-autodoc-guide: docs/advanced.md

const std = @import("std");
const expectEq = std.testing.expectEqual;

pub const statistics = @import("./util/statistics.zig");
const Statistics = statistics.Statistics;
const Color = @import("./util/color.zig").Color;
const format = @import("./util/format.zig");
const Optional = @import("./util/optional.zig").Optional;
const optional = @import("./util/optional.zig").optional;
const platform = @import("./util/platform.zig");
const Runner = @import("./util/runner.zig");
const Readings = Runner.Readings;
const AllocationReading = Runner.AllocationReading;
const TrackingAllocator = @import("./util/tracking_allocator.zig");

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

    /// Track memory allocations made using the Allocator provided to
    /// benchmarks.
    track_allocations: bool = false,
};

/// A benchmark definition.
const Definition = struct {
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
    fn run(self: Definition, allocator: std.mem.Allocator) !Runner.Reading {
        // Put the implementation into another function so we can put a
        // tracking allocator on the stack if requested.
        if (self.config.track_allocations) {
            var tracking = TrackingAllocator.init(allocator);
            return self.runImpl(tracking.allocator(), &tracking);
        } else return self.runImpl(allocator, null);
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
            .allocation = if (tracking) |trk| AllocationReading{
                .max = trk.maxAllocated(),
                .count = trk.allocationCount(),
            } else null,
        };
    }
};

/// A function pointer type that represents a benchmark function.
pub const BenchFunc = *const fn (std.mem.Allocator) void;

/// A function pointer type that represents a parameterised benchmark function.
pub const ParameterisedFunc = *const fn (*const anyopaque, std.mem.Allocator) void;

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
            .defn = .{ .simple = func },
            .config = optional(Config, config, self.common_config),
        });
    }

    /// Add a benchmark function to be timed with `run()`.
    pub fn addParam(
        self: *Benchmark,
        name: []const u8,
        benchmark: anytype,
        config: Optional(Config),
    ) !void {
        // Check the benchmark parameter is the proper type.
        const T: type = switch (@typeInfo(@TypeOf(benchmark))) {
            .Pointer => |ptr| if (ptr.is_const) ptr.child else @compileError(
                "benchmark must be a const ptr to a struct with a 'run' method",
            ),
            else => @compileError(
                "benchmark must be a const ptr to a struct with a 'run' method",
            ),
        };

        // Check the benchmark parameter has a well typed run function.
        _ = @as(fn (T, std.mem.Allocator) void, T.run);

        try self.benchmarks.append(self.allocator, Definition{
            .name = name,
            .defn = .{ .parameterised = .{
                .func = @ptrCast(&T.run),
                .context = @ptrCast(benchmark),
            } },
            .config = optional(Config, config, self.common_config),
        });
    }

    /// An incremental API for getting progress updates on running benchmarks.
    pub const Iterator = struct {
        allocator: std.mem.Allocator,
        b: *const Benchmark,
        remaining: []const Definition,
        runner: ?Runner,

        /// A summary of progress through benchmarking a function. The
        /// total_runs field may vary over time as the runner calibrates how
        /// many runs to perform.
        pub const Progress = struct {
            total_benchmarks: usize,
            completed_benchmarks: usize,
            current_name: []const u8,
            total_runs: usize,
            completed_runs: usize,
        };

        /// A progress update from the iterator; reports either that it's some
        /// way through benchmarking a function, or it has collected the results
        /// for a benchmark.
        pub const Step = union(enum) {
            progress: Progress,
            result: Result,
        };

        /// Get the next response.
        pub fn next(self: *Iterator) !?Step {
            if (self.remaining.len == 0) return null;

            var runner: *Runner = if (self.runner) |*r| r else blk: {
                const config = self.remaining[0].config;
                if (config.hooks.before_all) |hook| hook();
                self.runner = try Runner.init(
                    self.allocator,
                    config.iterations,
                    config.max_iterations,
                    config.time_budget_ns,
                    config.track_allocations,
                );
                break :blk &self.runner.?;
            };

            const runner_step = blk: {
                errdefer self.abort();
                const reading = try self.remaining[0].run(self.allocator);
                break :blk try runner.next(reading);
            };
            if (runner_step) |_| {
                const total_benchmarks = self.b.benchmarks.items.len;
                const remaining_benchmarks = self.remaining.len;
                const runner_status = runner.status();
                return Step{ .progress = Progress{
                    .total_benchmarks = total_benchmarks,
                    .completed_benchmarks = total_benchmarks - remaining_benchmarks,
                    .current_name = self.remaining[0].name,
                    .total_runs = runner_status.total_runs,
                    .completed_runs = runner_status.completed_runs,
                } };
            } else {
                defer self.runner = null;
                defer self.remaining = self.remaining[1..];
                if (self.remaining[0].config.hooks.after_all) |hook| hook();
                return Step{ .result = try Result.init(
                    self.remaining[0].name,
                    try runner.finish(),
                ) };
            }
        }

        /// Clean up the iterator if an error has occurred.
        pub fn abort(self: *Iterator) void {
            if (self.runner) |*r| {
                if (self.remaining[0].config.hooks.after_all) |hook| hook();
                r.abort();
            }
        }
    };

    /// Run all benchmarks using an iterator, collecting progress information
    /// incrementally.
    pub fn iterator(self: *const Benchmark) !Iterator {
        return Iterator{
            .allocator = self.allocator,
            .b = self,
            .remaining = self.benchmarks.items,
            .runner = null,
        };
    }

    /// Run all benchmarks and collect timing information.
    pub fn run(self: Benchmark, writer: anytype) !void {
        // Most allocations for pretty printing will be the same size each time,
        // so using an arena should reduce the allocation load.
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        try prettyPrintHeader(writer);

        var iter = try self.iterator();
        while (try iter.next()) |step| switch (step) {
            .progress => |_| {},
            .result => |x| {
                defer x.deinit();

                try x.prettyPrint(arena.allocator(), writer, true);
                _ = arena.reset(.retain_capacity);
            },
        };
    }
};

/// Write the prettyPrint() header to a writer.
pub fn prettyPrintHeader(writer: anytype) !void {
    try writer.print(
        "{s:<22} {s:<8} {s:<14} {s:<22} {s:<28} {s:<10} {s:<10} {s:<10}\n",
        .{
            "benchmark",
            "runs",
            "total time",
            "time/run (avg ± σ)",
            "(min ... max)",
            "p75",
            "p99",
            "p995",
        },
    );
    const dashes = "-------------------------";
    try writer.print(dashes ++ dashes ++ dashes ++ dashes ++ dashes ++ "\n", .{});
}

/// Get a copy of the system information, cpu type, cores, memory, etc.
pub fn getSystemInfo() !platform.OsInfo {
    return try platform.getSystemInfo();
}

/// Carries the results of a benchmark. The benchmark name and the recorded
/// durations are available, and some basic statistics are automatically
/// calculated.
pub const Result = struct {
    name: []const u8,
    readings: Readings,

    pub fn init(name: []const u8, readings: Runner.Readings) !Result {
        return Result{ .name = name, .readings = readings };
    }

    pub fn deinit(self: Result) void {
        self.readings.deinit();
    }

    /// Formats and prints the benchmark result in a human readable format.
    /// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
    /// colors: Whether to pretty-print with ANSI colors or not.
    pub fn prettyPrint(
        self: Result,
        allocator: std.mem.Allocator,
        writer: anytype,
        colors: bool,
    ) !void {
        var buf: [128]u8 = undefined;

        const timings_ns = self.readings.timings_ns;
        const s = try Statistics(u64).init(allocator, timings_ns);
        const truncated_name = self.name[0..@min(22, self.name.len)];
        // Benchmark name, number of iterations, and total time
        try writer.print("{s:<22} ", .{truncated_name});
        try setColor(colors, writer, Color.cyan);
        try writer.print("{d:<8} {s:<15}", .{
            self.readings.iterations,
            std.fmt.fmtDuration(s.total),
        });
        // Mean + standard deviation
        try setColor(colors, writer, Color.green);
        try writer.print("{s:<23}", .{
            try std.fmt.bufPrint(&buf, "{:.3} ± {:.3}", .{
                std.fmt.fmtDuration(s.mean),
                std.fmt.fmtDuration(s.stddev),
            }),
        });
        // Minimum and maximum
        try setColor(colors, writer, Color.blue);
        try writer.print("{s:<29}", .{
            try std.fmt.bufPrint(&buf, "({:.3} ... {:.3})", .{
                std.fmt.fmtDuration(s.min),
                std.fmt.fmtDuration(s.max),
            }),
        });
        // Percentiles
        try setColor(colors, writer, Color.cyan);
        try writer.print("{:<10} {:<10} {:<10}", .{
            std.fmt.fmtDuration(s.percentiles.p75),
            std.fmt.fmtDuration(s.percentiles.p99),
            std.fmt.fmtDuration(s.percentiles.p995),
        });
        // End of line
        try setColor(colors, writer, Color.reset);
        try writer.writeAll("\n");

        if (self.readings.allocations) |allocs| {
            const m = try Statistics(usize).init(allocator, allocs.maxes);
            // Benchmark name
            const name = try std.fmt.bufPrint(&buf, "{s} [MEMORY]", .{
                truncated_name,
            });
            try writer.print("{s:<46} ", .{name});
            // Mean + standard deviation
            try setColor(colors, writer, Color.green);
            try writer.print("{s:<23}", .{
                try std.fmt.bufPrint(&buf, "{:.3} ± {:.3}", .{
                    std.fmt.fmtIntSizeBin(m.mean),
                    std.fmt.fmtIntSizeBin(m.stddev),
                }),
            });
            // Minimum and maximum
            try setColor(colors, writer, Color.blue);
            try writer.print("{s:<29}", .{
                try std.fmt.bufPrint(&buf, "({:.3} ... {:.3})", .{
                    std.fmt.fmtIntSizeBin(m.min),
                    std.fmt.fmtIntSizeBin(m.max),
                }),
            });
            // Percentiles
            try setColor(colors, writer, Color.cyan);
            try writer.print("{:<10.3} {:<10.3} {:<10.3}", .{
                std.fmt.fmtIntSizeBin(m.percentiles.p75),
                std.fmt.fmtIntSizeBin(m.percentiles.p99),
                std.fmt.fmtIntSizeBin(m.percentiles.p995),
            });
            // End of line
            try setColor(colors, writer, Color.reset);
            try writer.writeAll("\n");
        }
    }

    fn setColor(colors: bool, writer: anytype, color: Color) !void {
        if (colors) try writer.writeAll(color.code());
    }

    pub fn writeJSON(
        self: Result,
        allocator: std.mem.Allocator,
        writer: anytype,
    ) !void {
        const timings_ns_stats =
            try Statistics(u64).init(allocator, self.readings.timings_ns);
        if (self.readings.allocations) |allocs| {
            const allocation_maxes_stats =
                try Statistics(usize).init(allocator, allocs.maxes);
            try writer.print(
                \\{{ "name": "{s}",
                \\   "timing_statistics": {}, "timings": {},
                \\   "max_allocation_statistics": {}, "max_allocations": {} }}
            ,
                .{
                    std.fmt.fmtSliceEscapeLower(self.name),
                    statistics.fmtJSON(u64, "nanoseconds", timings_ns_stats),
                    format.fmtJSONArray(u64, self.readings.timings_ns),
                    statistics.fmtJSON(usize, "bytes", allocation_maxes_stats),
                    format.fmtJSONArray(usize, allocs.maxes),
                },
            );
        } else {
            try writer.print(
                \\{{ "name": "{s}",
                \\   "timing_statistics": {}, "timings": {} }}
            ,
                .{
                    std.fmt.fmtSliceEscapeLower(self.name),
                    statistics.fmtJSON(u64, "nanoseconds", timings_ns_stats),
                    format.fmtJSONArray(u64, self.readings.timings_ns),
                },
            );
        }
    }
};
