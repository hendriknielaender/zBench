const std = @import("std");
const test_alloc = std.testing.allocator;
const print = std.debug.print;

const Benchmark = @import("./zbench.zig").Benchmark;

test "benchmark run bench" {
    var bench = try Benchmark.init("whatever", test_alloc);

    const Runner = struct {
        const Self = @This();

        pub fn init(_: std.mem.Allocator) !Self { return Self{}; }
        pub fn run(_: Self) !void {}
    };

    _ = try bench.runBench(Runner, 1000, 128);
}
