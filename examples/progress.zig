const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn myBenchmark1(_: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..100_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
    }
}

fn myBenchmark2(_: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..200_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
    }
}

test "bench test progress" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(test_allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark 1", myBenchmark1, .{});
    try bench.add("My Benchmark 2", myBenchmark2, .{});

    try stdout.writeAll("\n");
    try zbench.prettyPrintHeader(stdout);
    var iter = try bench.iterator();
    while (try iter.next()) |step| switch (step) {
        .progress => |_| {},
        .result => |x| {
            defer x.deinit();
            try x.prettyPrint(test_allocator, stdout, true);
        },
    };
}
