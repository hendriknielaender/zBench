const std = @import("std");
const c = @import("./util/color.zig");
const format = @import("./util/format.zig");

pub const Benchmark = struct {
    name: []const u8,
    N: usize = 1, // number of iterations
    timer: std.time.Timer,
    totalOperations: usize = 0,
    minDuration: u64 = 18446744073709551615, // full 64 bits as a start
    maxDuration: u64 = 0,
    totalDuration: u64 = 0,
    durations: std.ArrayList(u64),
    allocator: std.mem.Allocator,

    pub fn init(name: []const u8, allocator: std.mem.Allocator) !Benchmark {
        const bench = Benchmark{
            .name = name,
            .allocator = allocator,
            .timer = std.time.Timer.start() catch return error.TimerUnsupported,
            .durations = std.ArrayList(u64).init(allocator),
        };
        return bench;
    }

    // Start the benchmark
    pub fn start(self: *Benchmark) void {
        self.timer.reset();
    }

    // Stop the benchmark and record the duration
    pub fn stop(self: *Benchmark) void {
        const elapsedDuration = self.timer.read();
        self.totalDuration += elapsedDuration;

        if (elapsedDuration < self.minDuration) self.minDuration = elapsedDuration;
        if (elapsedDuration > self.maxDuration) self.maxDuration = elapsedDuration;

        self.durations.append(elapsedDuration) catch unreachable;
    }

    // Reset the benchmark
    pub fn reset(self: *Benchmark) void {
        self.totalOperations = 0;
        self.minDuration = 18446744073709551615;
        self.maxDuration = 0;
        self.totalDuration = 0;
        self.durations.deinit();
        self.durations = std.ArrayList(u64).init(self.allocator);
    }

    // Function to get elapsed time since benchmark start
    pub fn elapsed(self: *Benchmark) u64 {
        var sum: u64 = 0;
        for (self.durations.items) |duration| {
            sum += duration;
        }
        return sum;
    }

    pub fn setTotalOperations(self: *Benchmark, ops: usize) void {
        self.totalOperations = ops;
    }

    pub fn report(self: *Benchmark) void {
        std.debug.print("Total operations: {}\n", .{self.totalOperations});
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

    // Calculate the p75, p99, and p995 durations
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

    pub fn prettyPrint(self: Benchmark) !void {
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
        const min_str = try format.duration(min_buffer[0..], self.minDuration);

        var max_buffer: [128]u8 = undefined;
        const max_str = try format.duration(max_buffer[0..], self.maxDuration);

        std.debug.print("{s:<20} {s:<12} {s:<20} {s:<10} {s:<10} {s:<10}\n", .{ "benchmark", "time (avg)", "(min ... max)", "p75", "p99", "p995" });
        std.debug.print("--------------------------------------------------------------------------------------\n", .{});
        std.debug.print("{s:<20} \x1b[33m{s:<12}\x1b[0m (\x1b[94m{s}\x1b[0m ... \x1b[95m{s}\x1b[0m) \x1b[90m{s:<10}\x1b[0m \x1b[90m{s:<10}\x1b[0m \x1b[90m{s:<10}\x1b[0m\n", .{ self.name, avg_str, min_str, max_str, p75_str, p99_str, p995_str });
    }

    // Calculate the average duration
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
};

pub const BenchFunc = fn (*Benchmark) void;

pub const BenchmarkResult = struct {
    name: []const u8,
    duration: u64, // for total duration in nanoseconds
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
    defer bench.durations.deinit();
    const MIN_DURATION = 1_000_000_000; // minimum benchmark time in nanoseconds (1 second)
    const MAX_N = 65536; // maximum number of executions for the final benchmark run
    const MAX_ITERATIONS = 16384; // Define a maximum number of iterations

    bench.N = 1; // initial value; will be updated...
    var duration: u64 = 0;
    var iterations: usize = 0; // Add an iterations counter
    //var lastProgress: u8 = 0;

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

        // // Calculate the progress percentage
        // const progress = bench.N * 100 / MAX_N;
        //
        // // Print the progress if it's a new percentage
        // const currentProgress: u8 = @truncate(progress);
        // if (currentProgress != lastProgress) {
        //     std.debug.print("Preparing...({}%)\n", .{currentProgress});
        //     lastProgress = currentProgress;
        // }

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

    try bench.prettyPrint();
}
