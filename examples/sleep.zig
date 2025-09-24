const std = @import("std");
const zbench = @import("zbench");

fn sleepBenchmark(_: std.mem.Allocator) void {
    std.Thread.sleep(100_000_000);
}

pub fn main() !void {
    const stdout = std.fs.File.stdout();

    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();
    try bench.add("Sleep Benchmark", sleepBenchmark, .{});

    try bench.run(stdout);
}
