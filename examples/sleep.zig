const std = @import("std");
const zbench = @import("zbench");

fn sleepBenchmark(_: std.mem.Allocator) void {
    std.time.sleep(100_000_000);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();
    try bench.add("Sleep Benchmark", sleepBenchmark, .{});
    try stdout.writeAll("\n");
    try bench.run(stdout);
}
