const std = @import("std");
const zbench = @import("zbench");

fn noop(_: std.mem.Allocator) void {
    // does nothing
}

test "benchmark timer baseline" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.testing.allocator, .{});
    defer bench.deinit();

    try bench.add("Benchmark baseline, n=10", noop, .{
        .iterations = 10,
        .track_allocations = false,
    });

    try bench.add("Benchmark baseline, n=10k", noop, .{
        .iterations = 10_000,
        .track_allocations = false,
    });

    try bench.add("Benchmark baseline, n=10M", noop, .{
        .iterations = 10_000_000,
        .track_allocations = false,
    });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
