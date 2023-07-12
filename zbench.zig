const std = @import("std");
const c = @import("./util/color.zig");

pub const Timer = struct {
    startTime: i64 = 0,

    // Start the timer
    pub fn start(self: *Timer) void {
        self.startTime = std.time.milliTimestamp();
    }

    // Get elapsed time in milliseconds since the timer was started
    pub fn elapsed(self: Timer) u64 {
        return @intCast(std.time.milliTimestamp() - self.startTime);
    }

    // Reset the timer
    pub fn reset(self: *Timer) void {
        self.startTime = std.time.milliTimestamp();
    }
};

// B is passed to each benchmark function. It controls the benchmark
// and reports the results.
pub const Benchmark = struct {
    name: []const u8,
    timer: Timer,
    totalOperations: usize = 0,

    // Initialization function
    pub fn init(name: []const u8) Benchmark {
        var bench = Benchmark{
            .name = name,
            .timer = Timer{ .startTime = std.time.milliTimestamp() },
        };
        bench.timer.start();
        return bench;
    }

    // Function to get elapsed time since benchmark start
    pub fn elapsed(self: *Benchmark) u64 {
        return self.timer.elapsed();
    }

    pub fn incrementOperations(self: *Benchmark, ops: usize) void {
        self.totalOperations += ops;
    }

    pub fn report(self: *Benchmark) void {
        std.debug.print("Total operations: {}\n", .{self.totalOperations});
    }
};

// BenchFunc is a function that performs a benchmark.
pub const BenchFunc = fn (*Benchmark) void;

pub const BenchmarkResult = struct {
    name: []const u8,
    duration: u64, // Duration in milliseconds
};

pub const BenchmarkResults = struct {
    results: std.ArrayList(BenchmarkResult),

    // Calculate the relative performance and assign a color accordingly.
    pub fn getColor(self: *const BenchmarkResults, duration: u64) c.Color {
        const max_duration = @max(self.results.items[0].duration, self.results.items[self.results.items.len - 1].duration);
        const min_duration = @min(self.results.items[0].duration, self.results.items[self.results.items.len - 1].duration);

        if (duration <= min_duration) return c.Color.green;
        if (duration >= max_duration) return c.Color.red;

        const prop = (duration - min_duration) * 100 / (max_duration - min_duration + 1); // Multiply duration by 100 to create a percentage

        if (prop < 50) return c.Color.green; // Compare to 50, equivalent to comparing prop/100 < 0.5
        if (prop < 75) return c.Color.yellow; // Compare to 75, equivalent to comparing prop/100 < 0.75

        return c.Color.red;
    }

    // Pretty-print the benchmark results.
    pub fn prettyPrint(self: BenchmarkResults) !void {
        const stdout = std.io.getStdOut().writer();
        for (self.results.items) |result| {
            const color = self.getColor(result.duration);
            const formatted = try std.fmt.format(stdout, "{s}Benchmark: {s}\nDuration: {d} ms\n", .{ color.code(), result.name, result.duration });
            try stdout.print("{}", .{formatted});
        }
    }
};

// The benchmark function that takes a benchmark function and a name,
// performs the benchmark, and reports the results.
pub fn run(comptime func: BenchFunc, bench: *Benchmark, benchResult: *BenchmarkResults) !void {
    const iterations: usize = 1000;
    var j: usize = 0;
    while (j < iterations) : (j += 1) {
        func(bench);
    }
    const elapsed = bench.elapsed();
    std.debug.print("{s}: Elapsed time: {d} ms\n", .{ bench.name, elapsed });
    bench.report();
    try benchResult.results.append(BenchmarkResult{
        .name = bench.name,
        .duration = elapsed,
    });
}
