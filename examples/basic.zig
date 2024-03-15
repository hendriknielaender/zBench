const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn helloWorld() []const u8 {
    var result: usize = 0;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const square = i * i;
        result += square;
    }

    return "Hello, world!";
}

fn beforeAllHook() void {
    std.debug.print("Starting benchmarking...\n", .{});
}

fn afterAllHook() void {
    std.debug.print("Finished benchmarking.\n", .{});
}

fn myBenchmark(_: std.mem.Allocator) void {
    _ = helloWorld();
}

test "bench test basic" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(test_allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark", myBenchmark, .{
        .iterations = 10,
        .hooks = .{
            .before_all = beforeAllHook,
            .after_all = afterAllHook,
        },
    });

    const sysinfo = try bench.getSystemInfo();
    try std.fmt.format(stdout, "\n{}\n", .{sysinfo});

    const results = try bench.run();
    defer results.deinit();
    try results.prettyPrint(stdout, true);
}
