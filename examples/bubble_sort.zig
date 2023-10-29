const std = @import("std");
const inc = @import("include");
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

fn bubbleSort(nums: []i32) void {
    var i: usize = nums.len - 1;
    while (i > 0) : (i -= 1) {
        var j: usize = 0;
        while (j < i) : (j += 1) {
            if (nums[j] > nums[j + 1]) {
                var tmp = nums[j];
                nums[j] = nums[j + 1];
                nums[j + 1] = tmp;
            }
        }
    }
}

fn myBenchmark(b: *zbench.Benchmark) void {
    var numbers = [_]i32{ 4, 1, 3, 1, 5, 2 };
    _ = bubbleSort(&numbers);
    b.incrementOperations(1); // increment by 1 after each operation
}

test "bench test bubbleSort" {
    var customAllocator = CustomAllocator.create();
    var resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(customAllocator.allocator);
    var bench = try zbench.Benchmark.init("Bubble Sort Benchmark", customAllocator.as_mut());
    var benchmarkResults = zbench.BenchmarkResults{
        .results = resultsAlloc,
    };
    try zbench.run(myBenchmark, &bench, &benchmarkResults);
}
