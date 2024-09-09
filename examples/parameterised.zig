const std = @import("std");
const zbench = @import("zbench");

const MyBenchmark = struct {
    loops: usize,

    fn init(loops: usize) MyBenchmark {
        return .{ .loops = loops };
    }

    pub fn run(self: MyBenchmark, _: std.mem.Allocator) void {
        var result: usize = 0;
        for (0..self.loops) |i| {
            std.mem.doNotOptimizeAway(i);
            result += i * i;
        }
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.addParam("My Benchmark 1", &MyBenchmark.init(100_000), .{});
    try bench.addParam("My Benchmark 2", &MyBenchmark.init(200_000), .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
