const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn sooSleepy() void {
    std.time.sleep(100_000_000);
}

fn sleepBenchmark(_: *zbench.Benchmark) void {
    _ = sooSleepy();
}

test "bench test sleepy" {
    var bench = try zbench.Benchmark.init(test_allocator);
    defer bench.durations.deinit();
    try (try bench.runSingle(sleepBenchmark, .{ .name = "Sleepy benchmark" })).prettyPrint(true);
}
