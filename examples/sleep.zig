const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn sooSleepy() void {
    std.time.sleep(100_000_000);
}

fn sleepBenchmark(_: std.mem.Allocator) void {
    _ = sooSleepy();
}

test "bench test sleepy" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(test_allocator, .{});
    defer bench.deinit();

    try bench.add("Sleep Benchmark", sleepBenchmark, .{});

    const results = try bench.run();
    defer results.deinit();
    try results.prettyPrint(stdout, true);
}
