const std = @import("std");
const zbench = @import("zbench");

fn sleepyFirstRunner(_: std.mem.Allocator) void {
    std.time.sleep(100_000);
}

fn sleepySecondRunner(_: std.mem.Allocator) void {
    std.time.sleep(1_000_000);
}

fn sleepyThirdRunner(_: std.mem.Allocator) void {
    std.time.sleep(10_000_000);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const second: u64 = 1_000_000_000;
    const bench_iterations: u64 = 128;

    var bench = try zbench.Benchmark.init(second, bench_iterations, gpa.allocator());
    defer bench.deinit();

    const result1 = try bench.runBench(sleepyFirstRunner, "Sleepy-first benchmark");
    const result2 = try bench.runBench(sleepySecondRunner, "Sleepy-second benchmark");
    const result3 = try bench.runBench(sleepyThirdRunner, "Sleepy-third benchmark");

    try zbench.prettyPrintResults(&.{result1, result2, result3}, true);
}
