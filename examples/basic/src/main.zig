const std = @import("std");
const zbench = @import("zbench");

pub const CustomAllocator = struct {
    allocator: std.mem.Allocator,

    pub fn create() CustomAllocator {
        return CustomAllocator{ .allocator = std.heap.page_allocator };
    }

    pub fn as_mut(self: *CustomAllocator) *std.mem.Allocator {
        return &self.allocator;
    }
};

fn myBenchmark(b: *zbench.Benchmark) void {
    b.timer.start(); // Start the timer
    // Perform the benchmark here
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        // Simulating an operation
        b.incrementOperations(1);
    }
    b.timer.stop(); // Stop the timer
}

pub fn main() !void {
    var customAllocator = CustomAllocator.create();
    var resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(customAllocator.allocator);
    var bench = try zbench.Benchmark.init("My Benchmark", customAllocator.as_mut());

    var benchmarkResults = zbench.BenchmarkResults{
        .results = resultsAlloc,
    };

    try zbench.run(myBenchmark, &bench, &benchmarkResults);
}
