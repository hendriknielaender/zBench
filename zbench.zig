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

    pub fn stop(self: *Timer) void {
        self.startTime = 0;
    }
};

pub const Benchmark = struct {
    name: []const u8,
    timer: Timer,
    totalOperations: usize = 0,
    minDuration: u64 = 18446744073709551615,
    maxDuration: u64 = 0,
    durations: std.ArrayList(u64),

    // Initialization function
    pub fn init(name: []const u8, allocator: *std.mem.Allocator) !Benchmark {
        var bench = Benchmark{
            .name = name,
            .timer = Timer{ .startTime = std.time.milliTimestamp() },
            .durations = std.ArrayList(u64).init(allocator.*),
        };
        bench.timer.start();
        return bench;
    }

    // Start the benchmark
    pub fn start(self: *Benchmark) void {
        self.timer.start();
    }

    // Stop the benchmark and record the duration
    pub fn stop(self: *Benchmark) !void {
        try self.durations.append(self.timer.elapsed());
        const elapsedDuration = self.timer.elapsed();
        try self.durations.append(elapsedDuration);

        if (elapsedDuration < self.minDuration) self.minDuration = elapsedDuration;
        if (elapsedDuration > self.maxDuration) self.maxDuration = elapsedDuration;

        self.totalOperations += 1;
    }

    // Reset the benchmark
    pub fn reset(self: *Benchmark) void {
        self.timer.reset();
        self.totalOperations = 0;
        self.minDuration = 18446744073709551615;
        self.maxDuration = 0;
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

    pub const Percentiles = struct {
        p75: u64,
        p99: u64,
        p995: u64,
    };

    // Calculate the p75, p99, and p995 durations
    pub fn calculatePercentiles(self: Benchmark) Percentiles {
        const p75Index = (self.totalOperations * 75) / 100;
        const p99Index = (self.totalOperations * 99) / 100;
        const p995Index = (self.totalOperations * 995) / 1000;

        const p75 = self.durations[p75Index];
        const p99 = self.durations[p99Index];
        const p995 = self.durations[p995Index];

        return Percentiles{ .p75 = p75, .p99 = p99, .p995 = p995 };
    }

    pub fn prettyPrint(self: Benchmark) void {
        std.debug.print("--------------------------------------------------------------------------------------\n", .{});
        std.debug.print("Benchmark: {s}\n", .{self.name});
    }

    // Calculate the average duration
    pub fn calculateAverage(self: Benchmark) f64 {
        var sum: u64 = 0;
        for (self.durations) |duration| {
            sum += duration;
        }
        const total_operations_f64: f64 = @floatFromInt(self.totalOperations);
        const sum_f64: f64 = @floatFromInt(sum);
        return sum_f64 / total_operations_f64;
    }
};

pub const BenchFunc = fn (*Benchmark) void;

pub const BenchmarkResult = struct {
    name: []const u8,
    duration: u64, // Duration in milliseconds
};

pub const BenchmarkResults = struct {
    results: std.ArrayList(BenchmarkResult),

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

    pub fn prettyPrint(self: BenchmarkResults) !void {
        const stdout = std.io.getStdOut().writer();
        std.debug.print("--------------------------------------------------------------------------------------\n", .{});

        for (self.results.items) |result| {
            try stdout.print("{s}", .{result.name});
        }
    }
};

pub fn run(comptime func: BenchFunc, bench: *Benchmark, benchResult: *BenchmarkResults) !void {
    const iterations: usize = 1000;
    var j: usize = 0;
    while (j < iterations) : (j += 1) {
        bench.start();
        func(bench);
        try bench.stop(); // Propagate error
    }
    bench.prettyPrint();
    const elapsed = bench.elapsed();
    std.debug.print("{s}: Elapsed time: {d} ms\n", .{ bench.name, elapsed });
    bench.report();
    try benchResult.results.append(BenchmarkResult{
        .name = bench.name,
        .duration = elapsed,
    });
}
