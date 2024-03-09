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

fn myBenchmark(_: *zbench.Benchmark) void {
    _ = helloWorld();
}

test "bench test basic" {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(test_allocator);
    var benchmarkResults = zbench.BenchmarkResults.init(resultsAlloc);
    defer benchmarkResults.deinit();
    var bench = try zbench.Benchmark.init("My Benchmark", test_allocator, .{
        .iterations = 10,
        .display_system_info = true,
        .hooks = .{
            .beforeAll = beforeAllHook,
            .afterAll = afterAllHook,
        },
    });

    try zbench.run(myBenchmark, &bench, &benchmarkResults);
    try benchmarkResults.prettyPrint();
}
