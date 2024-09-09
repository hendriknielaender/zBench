const std = @import("std");
const zbench = @import("zbench");

fn beforeAllHook() void {
    std.debug.print("Starting benchmarking...\n", .{});
}

fn afterAllHook() void {
    std.debug.print("Finished benchmarking.\n", .{});
}

fn myBenchmark(_: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..1_000_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark", myBenchmark, .{
        .iterations = 100,
        .hooks = .{
            .before_all = beforeAllHook,
            .after_all = afterAllHook,
        },
    });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
