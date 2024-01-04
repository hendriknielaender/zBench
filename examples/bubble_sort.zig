const std = @import("std");
const inc = @import("include");
const zbench = @import("zbench");

const BubbleSortRunner = struct {
    const Self = @This();

    nums: [10]i32,

    pub fn init(_: std.mem.Allocator) !Self {
        return Self{ .nums = [_]i32{ 4, 1, 3, 1, 5, 2, 6, 0, 7, 8 } };
    }

    pub fn run(self: *Self) void {
        var i: usize = self.nums.len - 1;
        while (i > 0) : (i -= 1) {
            var j: usize = 0;
            while (j < i) : (j += 1) {
                if (self.nums[j] > self.nums[j + 1]) {
                    std.mem.swap(i32, &self.nums[j], &self.nums[j + 1]);
                }
            }
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const second: u64 = 1_000_000_000;
    const bench_iterations: u64 = 128;

    var bench = try zbench.Benchmark.init(second, bench_iterations, gpa.allocator());
    defer bench.deinit();

    const bench_result = try bench.run(BubbleSortRunner, "Bubble-sort bench");
    try bench_result.prettyPrint(true);
}
