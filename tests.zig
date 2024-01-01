const std = @import("std");
const test_alloc = std.testing.allocator;
const print = std.debug.print;

const Benchmark = @import("./zbench.zig").Benchmark;

test "benchmark runBench with standalone function" {
    var bench = try Benchmark.init(1000, 128, test_alloc);
    defer bench.deinit();

    const Nested = struct {
        pub fn run(_: std.mem.Allocator) void {}
    };

    _ = try bench.runBench(Nested.run, "test_bench");
}

test "benchmark runBench with enum runner with init and run" {
    var bench = try Benchmark.init(1000, 128, test_alloc);
    defer bench.deinit();

    const Runner = enum {
        const Self = @This();

        Variant,

        pub fn init(_: std.mem.Allocator) !Self { return Self.Variant; }
        pub fn run(_: *Self) void {}
    };

    _ = try bench.runBench(Runner, "test_bench");
}

test "benchmark runBench with struct runner with init, run and deinit" {
    var bench = try Benchmark.init(1000, 128, test_alloc);
    defer bench.deinit();

    const Runner = struct {
        const Self = @This();

        items: []u8,
        alloc: std.mem.Allocator,

        pub fn init(a: std.mem.Allocator) !Self {
            return Self { .items = try a.alloc(u8, 5), .alloc = a };
        }
        pub fn run(self: Self) void {
            if (self.items[1] >= self.items[2]) {
                self.items[2] = self.items[3];
            } else {
                self.items[1] = self.items[4];
            }
        }

        pub fn deinit(self: Self) void { self.alloc.free(self.items); }
    };

    _ = try bench.runBench(Runner, "test_bench");
}

test "benchmark runBench with complete bench-runner struct" {
    var bench = try Benchmark.init(1000, 128, test_alloc);
    defer bench.deinit();

    const Runner = struct {
        const Self = @This();

        items: []u64,
        alloc: std.mem.Allocator,

        pub fn init(a: std.mem.Allocator) !Self {
            return Self { .items = try a.alloc(u64, 64), .alloc = a };
        }
        pub fn run(self: Self) void {
            for (self.items, 0..) |*item, i| {
                if (item.* <= i) item.* = i else item.* = 0;
            }
        }
        pub fn deinit(self: Self) void {
            self.alloc.free(self.items);
        }
        pub fn reset(self: Self) void {
            @memset(self.items, 0);
        }
    };

    _ = try bench.runBench(Runner, "test_bench");
}
