const std = @import("std");
const zbench = @import("zbench");

const MyBenchmark = struct {
    loops: usize,

    fn init(loops: usize) MyBenchmark {
        return .{ .loops = loops };
    }

    pub fn run(self: *MyBenchmark, _: std.mem.Allocator) void {
        var result: usize = 0;
        for (0..self.loops) |i| {
            std.mem.doNotOptimizeAway(i);
            result += i * i;
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const stdout: std.Io.File = .stdout();

    var bench = zbench.Benchmark.init(init.gpa, .{});
    defer bench.deinit();

    try bench.addParam("My Benchmark 1", &MyBenchmark.init(100_000), .{});
    try bench.addParam("My Benchmark 2", &MyBenchmark.init(200_000), .{});
    try bench.run(io, stdout);
}
