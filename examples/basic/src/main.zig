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

fn helloWorld() []const u8 {
    var result: usize = 0;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const square = i * i;
        result += square;
    }

    return "Hello, world!";
}

fn myBenchmark(b: *zbench.Benchmark) void {
    _ = helloWorld();
    b.incrementOperations(1); // increment by 1 after each operation
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
