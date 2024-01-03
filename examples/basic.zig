const std = @import("std");
const zbench = @import("zbench");

fn helloWorld() []const u8 {
    var result: usize = 0;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const square = i * i;
        result += square;
    }

    return "Hello, world!";
}

fn myBenchRunner(_: std.mem.Allocator) void {
    _ = helloWorld();
}

const StructRunner = struct {
    const Self = @This();

    list: std.ArrayList(usize),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !Self {
        return Self {
            .list = try std.ArrayList(usize).initCapacity(alloc, 512),
            .alloc = alloc,
        };
    }

    pub fn run(self: *Self) void {
        for (0..512) |i| self.list.append(i) catch @panic("Append failed!");
    }

    pub fn reset(self: *Self) void {
        self.list.clearRetainingCapacity();
    }

    pub fn deinit(self: Self) void { self.list.deinit(); }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const second: u64 = 1_000_000_000;
    const bench_iterations: u64 = 128;

    var bench = try zbench.Benchmark.init(second, bench_iterations, gpa.allocator());
    defer bench.deinit();

    const bench_result = try bench.run(StructRunner, "ArrayList append");
    try bench_result.prettyPrint(true);
}
