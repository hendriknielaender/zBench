const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn fastFunction(_: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..1_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
    }
}
fn mediumFunction(_: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..20_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
    }
}
fn slowFunction(_: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..300_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
    }
}

test "bench test summary" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.testing.allocator, .{
        .display_summary = true,
    });
    defer bench.deinit();

    try bench.add("fast function", fastFunction, .{
        .iterations = 10,
    });

    try bench.add("medium fast function", mediumFunction, .{
        .iterations = 10,
    });

    try bench.add("slow function", slowFunction, .{
        .iterations = 10,
    });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
