const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

const MyBenchmark = struct {
    loops: usize,

    fn init(loops: usize) MyBenchmark {
        return .{ .loops = loops };
    }

    pub fn run(self: MyBenchmark, _: std.mem.Allocator) void {
        var result: usize = 0;
        for (0..self.loops) |i| result += i * i;
    }
};

test "bench test parameterised" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(test_allocator, .{});
    defer bench.deinit();

    try bench.addParam("My Benchmark 1", &MyBenchmark.init(100_000), .{});
    try bench.addParam("My Benchmark 2", &MyBenchmark.init(200_000), .{});

    const results = try bench.run();
    defer results.deinit();
    try stdout.writeAll("\n");
    try results.prettyPrint(stdout, true);
}
