const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn sooSleepy() void {
    std.time.sleep(100_000_000);
}

fn sleepBenchmark(_: *zbench.Benchmark) void {
    _ = sooSleepy();
}

test "bench test sleepy" {
    var bench = try zbench.Benchmark.init("Sleep Benchmark", test_allocator);
    var resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(test_allocator);
    var benchmarkResults = zbench.BenchmarkResults{
        .results = resultsAlloc,
    };
    defer benchmarkResults.results.deinit();

    try zbench.run(sleepBenchmark, &bench, &benchmarkResults);
}
