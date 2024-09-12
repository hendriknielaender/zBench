// This example shows how to use hooks to provide more control over a benchmark.
// The bubble_sort.zig example is enhanced with randomly generated numbers.
// Global strategy:
// * At the start of the benchmark, i.e., before the first iteration, we allocate an ArrayList and setup a random number generator.
// * Before each iteration, we fill the ArrayList with random numbers.
// * After each iteration, we reset the ArrayList while keeping the allocated memory.
// * At the end of the benchmark, we deinit the ArrayList.
const std = @import("std");
const inc = @import("include");
const zbench = @import("zbench");

// Global variables modified/accessed by the hooks.
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const array_size: usize = 100;
// BenchmarkData contains the data generation logic.
var benchmark_data: BenchmarkData = undefined;

// Hooks do not accept any parameters and cannot return anything.
fn beforeAll() void {
    benchmark_data.init(gpa.allocator(), array_size) catch unreachable;
}

fn beforeEach() void {
    benchmark_data.fill();
}

fn myBenchmark(_: std.mem.Allocator) void {
    bubbleSort(benchmark_data.numbers.items);
}

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

fn afterEach() void {
    benchmark_data.reset();
}

fn afterAll() void {
    benchmark_data.deinit();
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var bench = zbench.Benchmark.init(gpa.allocator(), .{});
    defer {
        bench.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.panic("Memory leak detected", .{});
    }

    try bench.add("Bubble Sort Benchmark", myBenchmark, .{
        .track_allocations = true, // Option used to show that hooks are not included in the tracking.
        .hooks = .{ // Fields are optional and can be omitted.
            .before_all = beforeAll,
            .after_all = afterAll,
            .before_each = beforeEach,
            .after_each = afterEach,
        },
    });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}

const BenchmarkData = struct {
    rand: std.Random,
    numbers: std.ArrayList(i32),
    prng: std.Random.DefaultPrng,

    pub fn init(self: *BenchmarkData, allocator: std.mem.Allocator, num: usize) !void {
        self.prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
            break :blk seed;
        });
        self.rand = self.prng.random();
        self.numbers = try std.ArrayList(i32).initCapacity(allocator, num);
    }

    pub fn deinit(self: BenchmarkData) void {
        self.numbers.deinit();
    }

    pub fn fill(self: *BenchmarkData) void {
        for (0..self.numbers.capacity) |_| {
            self.numbers.appendAssumeCapacity(self.rand.intRangeAtMost(i32, 0, 100));
        }
    }

    pub fn reset(self: *BenchmarkData) void {
        self.numbers.clearRetainingCapacity();
    }
};
