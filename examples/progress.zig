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
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const writer = &stdout_writer.interface;

    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark 1", myBenchmark1, .{});
    try bench.add("My Benchmark 2", myBenchmark2, .{});

    try writer.writeAll("\n");
    try zbench.prettyPrintHeader(writer);
    var iter = try bench.iterator();
    while (try iter.next()) |step| switch (step) {
        .progress => |_| {},
        .result => |x| {
            defer x.deinit();
            try x.prettyPrint(allocator, writer, true);
        },
    };
    try writer.flush();
}
