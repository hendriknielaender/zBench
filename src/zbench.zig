//!zig-autodoc-guide: ../docs/intro.md
//!zig-autodoc-guide: ../docs/quickstart.md
//!zig-autodoc-guide: ../docs/advanced.md

const std = @import("std");

// Export public API
pub const Config = @import("benchmark.zig").Config;
pub const Hooks = @import("benchmark.zig").Hooks;
pub const Definition = @import("benchmark.zig").Definition;
pub const BenchFunc = @import("benchmark.zig").BenchFunc;
pub const ParameterisedFunc = @import("benchmark.zig").ParameterisedFunc;
pub const Result = @import("result.zig").Result;
pub const statistics = @import("statistics.zig");

// Internal imports
const Runner = @import("runner.zig");
const Readings = Runner.Readings;
const AllocationReading = Runner.AllocationReading;
const TrackingAllocator = @import("allocators/tracking_allocator.zig");
const ShufflingAllocator = @import("allocators/shuffling_allocator.zig").ShufflingAllocator;
const Partial = @import("partial.zig").Partial;
const partial = @import("partial.zig").partial;
const platform = @import("platform/platform.zig");
const Color = std.Io.tty.Color;

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
        config: Partial(Config),
    ) !void {
        try self.benchmarks.append(self.allocator, Definition{
            .name = name,
            .defn = .{ .simple = func },
            .config = partial(Config, config, self.common_config),
        });
    }

    /// Add a benchmark function to be timed with `run()`.
    pub fn addParam(
        self: *Benchmark,
        name: []const u8,
        benchmark: anytype,
        config: Partial(Config),
    ) !void {
        // Check the benchmark parameter is the proper type.
        const T: type = switch (@typeInfo(@TypeOf(benchmark))) {
            .pointer => |ptr| if (ptr.is_const) ptr.child else @compileError(
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
            .config = partial(Config, config, self.common_config),
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
                return Step{ .result = Result.init(
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
    pub fn run(self: Benchmark, writer: *std.Io.Writer) !void {
        // Most allocations for pretty printing will be the same size each time,
        // so using an arena should reduce the allocation load.
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        try prettyPrintHeader(writer);

        // Detect TTY configuration for color output
        const tty_config = std.Io.tty.Config.detect(std.fs.File.stdout());

        var iter = try self.iterator();
        while (try iter.next()) |step| switch (step) {
            .progress => |_| {},
            .result => |x| {
                defer x.deinit();

                try x.prettyPrint(arena.allocator(), writer, tty_config);
                _ = arena.reset(.retain_capacity);
            },
        };
    }
};

/// Write the prettyPrint() header to a writer.
pub fn prettyPrintHeader(writer: *std.Io.Writer) !void {
    try writer.print(
        "{s:<22} {s:<8} {s:<14} {s:<23} {s:<28} {s:<10} {s:<10} {s:<10}\n",
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

test {
    std.testing.refAllDecls(@This());
}
