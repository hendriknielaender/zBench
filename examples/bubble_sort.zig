const std = @import("std");
const inc = @import("include");
const zbench = @import("zbench");

fn bubbleSort(nums: []i32) void {
    var i: usize = nums.len - 1;
    while (i > 0) : (i -= 1) {
        var j: usize = 0;
        while (j < i) : (j += 1) {
            if (nums[j] > nums[j + 1]) {
                std.mem.swap(i32, &nums[j], &nums[j + 1]);
            }
        }
    }
}

fn myBenchmark(_: std.mem.Allocator) void {
    var numbers = [_]i32{ 4, 1, 3, 1, 5, 2 };
    _ = bubbleSort(&numbers);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.add("Bubble Sort Benchmark", myBenchmark, .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
