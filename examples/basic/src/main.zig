const std = @import("std");
const zbench = @import("zbench");

fn myBenchmark(b: *zbench.Benchmark) void {
    b.timer.start(); // Start the timer
    // Perform the benchmark here
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        // Simulating an operation
        b.incrementOperations(1);
    }
}

pub fn main() !void {
    var benchmarkResults = zbench.BenchmarkResults{
        .results = std.ArrayList(zbench.BenchmarkResult).init(std.heap.page_allocator),
    };

    var bench = zbench.Benchmark.init("myBenchmark");
    try zbench.run(myBenchmark, &bench, &benchmarkResults);

    // After all benchmarks have been run...
    try benchmarkResults.prettyPrint();
}
