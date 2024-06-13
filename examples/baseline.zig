const std = @import("std");
const zbench = @import("zbench");

fn noop(_: std.mem.Allocator) void {
    // does nothing
}

test "benchmark timer baseline" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.testing.allocator, .{});
    defer bench.deinit();

    try bench.add("Correction off, n=10 ", noop, .{
        .iterations = 10,
        .baseline_correction = false,
    });
    try bench.add("Correction on,  n=10 ", noop, .{
        .iterations = 10,
        .baseline_correction = true,
    });

    try bench.add("Correction off, n=1k ", noop, .{
        .iterations = 1_000,
        .baseline_correction = false,
    });
    try bench.add("Correction on,  n=1k ", noop, .{
        .iterations = 1_000,
        .baseline_correction = true,
    });

    try bench.add("Correction off, n=10k", noop, .{
        .iterations = 10_000,
        .baseline_correction = false,
    });

    try bench.add("Correction on,  n=10k", noop, .{
        .iterations = 10_000,
        .baseline_correction = true,
    });

    try bench.add("Correction off, n=1M ", noop, .{
        .iterations = 1_000_000,
        .baseline_correction = false,
    });

    try bench.add("Correction on,  n=1M ", noop, .{
        .iterations = 1_000_000,
        .baseline_correction = true,
    });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
