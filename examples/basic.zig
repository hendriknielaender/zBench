const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn helloWorld() []const u8 {
    var result: usize = 0;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const square = i * i;
        result += square;
    }

    return "Hello, world!";
}

fn myBenchmark(_: *zbench.Benchmark) void {
    _ = helloWorld();
}

test "bench test basic" {
    var bench = try zbench.Benchmark.init(test_allocator);
    defer bench.durations.deinit();
    try (try bench.runSingle(myBenchmark, .{ .name = "Basic benchmark" })).prettyPrint(true);
}
