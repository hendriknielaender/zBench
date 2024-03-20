const std = @import("std");
const zbench = @import("zbench");

fn myBenchmark(_: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..1_000_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
    }
}

test "bench test basic" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.testing.allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark", myBenchmark, .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
