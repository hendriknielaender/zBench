const std = @import("std");
const c = @import("./util/color.zig");

pub const Timer = struct {
    startTime: u64 = 0,
    elapsedTime: u64 = 0,

    pub fn start(self: *Timer) void {
        self.startTime = @intCast(std.time.microTimestamp());
    }

    pub fn stop(self: *Timer) void {
        if (self.startTime != 0) {
            var stamp: u64 = @intCast(std.time.microTimestamp());
            self.elapsedTime = stamp - self.startTime;
        }
        self.startTime = 0;
    }

    pub fn elapsed(self: Timer) u64 {
        if (self.startTime == 0) {
            return self.elapsedTime;
        } else {
            var stamp: u64 = @intCast(std.time.microTimestamp());
            return stamp - self.startTime;
        }
    }

    pub fn reset(self: *Timer) void {
        self.startTime = @intCast(std.time.microTimestamp());
    }
};

pub fn formatDuration(duration: u64) ![]u8 {
    const units = [_][]const u8{ "ns", "µs", "ms", "s" };

    var scaledDuration: u64 = duration;
    var unitIndex: usize = 0;

    var fractionalPart: u64 = 0;

    while (scaledDuration >= 1_000 and unitIndex < units.len - 1) {
        fractionalPart = scaledDuration % 1_000;
        scaledDuration /= 1_000;
        unitIndex += 1;
    }

    var buffer: [128]u8 = undefined; // You can adjust the size of this buffer as needed
    const formatted = try std.fmt.bufPrint(&buffer, "{d}.{d}{s}", .{ scaledDuration, fractionalPart, units[unitIndex] });

    return formatted;
}

pub const Benchmark = struct {
    name: []const u8,
    timer: Timer,
    totalOperations: usize = 0,
    minDuration: u64 = 18446744073709551615,
    maxDuration: u64 = 0,
    durations: std.ArrayList(u64),
    allocator: *std.mem.Allocator,

    pub fn init(name: []const u8, allocator: *std.mem.Allocator) !Benchmark {
        var startTime: u64 = @intCast(std.time.microTimestamp());
        if (startTime < 0) {
            std.debug.warn("Failed to get start time. Defaulting to 0.\n", .{});
            startTime = 0;
        }

        var bench = Benchmark{
            .name = name,
            .timer = Timer{ .startTime = startTime },
            .durations = std.ArrayList(u64).init(allocator.*),
            .allocator = allocator,
        };
        bench.timer.start();
        return bench;
    }

    // Start the benchmark
    pub fn start(self: *Benchmark) void {
        self.timer.start();
        self.startTime = self.timer.startTime;
    }

    // Stop the benchmark and record the duration
    pub fn stop(self: *Benchmark) !void {
        const elapsedDuration = self.timer.elapsed();
        try self.durations.append(elapsedDuration);

        if (elapsedDuration < self.minDuration) self.minDuration = elapsedDuration;
        if (elapsedDuration > self.maxDuration) self.maxDuration = elapsedDuration;

        self.totalOperations += 1;
        self.timer.reset();
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

    fn insertionSort(arr: []u64) void {
        var i: usize = 1;
        while (i < arr.len) : (i += 1) {
            var j: usize = i;
            while (j > 0 and arr[j - 1] > arr[j]) : (j -= 1) {
                const temp = arr[j];
                arr[j] = arr[j - 1];
                arr[j - 1] = temp;
            }
        }
    }

    // Calculate the p75, p99, and p995 durations
    pub fn calculatePercentiles(self: Benchmark) Percentiles {
        // Sort the durations in ascending order
        insertionSort(self.durations.items);

        const p75Index = @min((self.durations.items.len * 75) / 100, self.durations.items.len - 1);
        const p99Index = ((self.durations.items.len - 1) * 99) / 100;
        const p995Index = @min((self.durations.items.len * 995) / 1000, self.durations.items.len - 1);

        const p75 = self.durations.items[p75Index];
        const p99 = self.durations.items[p99Index];
        const p995 = self.durations.items[p995Index];

        return Percentiles{ .p75 = p75, .p99 = p99, .p995 = p995 };
    }

    pub fn prettyPrint(self: Benchmark) !void {
        const percentiles = self.calculatePercentiles();
        var p75: []u8 = try formatDuration(percentiles.p75);
        var p99: []u8 = try formatDuration(percentiles.p99);
        var p995: []u8 = try formatDuration(percentiles.p995);

        var avg: u64 = @intFromFloat(self.calculateAverage());

        std.debug.print("{s:<20} {s:<12} {s:<20} {s:<10} {s:<10} {s:<10}\n", .{ "benchmark", "time (avg)", "(min ... max)", "p75", "p99", "p995" });
        std.debug.print("--------------------------------------------------------------------------------------\n", .{});
        std.debug.print("{s:<20} {s:<12} ({s} ... {s}) {s:<10} {s:<10} {s:<10}\n", .{ self.name, try formatDuration(avg), try formatDuration(self.minDuration), try formatDuration(self.maxDuration), p75, p99, p995 });
    }

    // Calculate the average duration
    pub fn calculateAverage(self: Benchmark) f64 {
        var sum: f64 = 0;
        for (self.durations.items) |duration| {
            var duration_f64: f64 = @floatFromInt(duration); // Explicitly cast u64 to f64
            sum += duration_f64;
        }
        var total_operations_f64: f64 = @floatFromInt(self.totalOperations); // Explicitly cast usize to f64
        return sum / total_operations_f64;
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
    const iterations: usize = 1;
    var j: usize = 0;
    while (j < iterations) : (j += 1) {
        bench.reset();
        func(bench);
        const elapsed = bench.elapsed();
        try bench.stop();
        try benchResult.results.append(BenchmarkResult{
            .name = bench.name,
            .duration = elapsed,
        });
    }
    try bench.prettyPrint();
    bench.report();
}
