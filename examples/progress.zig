const std = @import("std");
const zbench = @import("zbench");

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

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    const writer = &stdout.interface;

    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark 1", myBenchmark1, .{});
    try bench.add("My Benchmark 2", myBenchmark2, .{});

    try writer.writeAll("\n");
    try zbench.prettyPrintHeader(writer);

    // Detect TTY configuration for color output
    const tty_config = std.io.tty.Config.detect(std.fs.File.stdout());

    var iter = try bench.iterator();
    while (try iter.next()) |step| switch (step) {
        .progress => |_| {},
        .result => |x| {
            defer x.deinit();
            try x.prettyPrint(allocator, writer, tty_config);
        },
    };
}
