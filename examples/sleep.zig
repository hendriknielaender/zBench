const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn sleepBenchmark(_: std.mem.Allocator) void {
    std.time.sleep(100_000_000);
}

test "bench test sleepy" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(test_allocator, .{});
    defer bench.deinit();
    try bench.add("Sleep Benchmark", sleepBenchmark, .{});
    try stdout.writeAll("\n");
    try bench.run(stdout);
}
