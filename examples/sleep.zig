const std = @import("std");
const zbench = @import("zbench");
const log = std.log.scoped(.zbench_example_sleep);

var threaded: std.Io.Threaded = .init_single_threaded;
const io = threaded.io();

fn sleepBenchmark(_: std.mem.Allocator) void {
    io.sleep(.fromMilliseconds(100), .awake) catch |err| {
        log.err("sleep failed: {}", .{err});
    };
}

pub fn main() !void {
    var stdout: std.Io.File.Writer = std.Io.File.stdout().writerStreaming(io, &.{});
    const writer = &stdout.interface;

    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();
    try bench.add("Sleep Benchmark", sleepBenchmark, .{});

    try writer.writeAll("\n");
    try bench.run(writer);
}
