const std = @import("std");
const zbench = @import("zbench");
const log = std.log.scoped(.zbench_example_sleep);

// using a global io here so we can use it in the benchmarked function implicitly
var threaded: std.Io.Threaded = .init_single_threaded;
const io = threaded.io();

fn sleepBenchmark(_: std.mem.Allocator) void {
    io.sleep(.fromMilliseconds(100), .awake) catch |err| {
        log.err("sleep failed: {}", .{err});
    };
}

pub fn main() !void {
    const stdout: std.Io.File = .stdout();

    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.add("Sleep Benchmark", sleepBenchmark, .{});
    try bench.run(io, stdout);
}
