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

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const stdout: std.Io.File = .stdout();

    var bench = zbench.Benchmark.init(init.gpa, .{});
    defer bench.deinit();

    try bench.add("My Benchmark", myBenchmark, .{
        .iterations = 100,
        .hooks = .{
            .before_all = beforeAllHook,
            .after_all = afterAllHook,
        },
    });
    try bench.run(io, stdout);
}
