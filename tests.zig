const std = @import("std");
const test_alloc = std.testing.allocator;
const print = std.debug.print;
const expectEq = std.testing.expectEqual;

const Benchmark = @import("./zbench.zig").Benchmark;

test "benchmark run with standalone function" {
    const runs: usize = 128;
    var bench = try Benchmark.init(std.math.maxInt(u64), runs, test_alloc);
    defer bench.deinit();

    const Nested = struct {
        pub fn run(_: std.mem.Allocator) void {}
    };

    const res = try bench.run(Nested.run, "test_bench");

    // We set no time-limit, so it should perform all the runs requested
    try expectEq(runs, res.total_operations);

    // We also expect the Benchmark instance to be reset
    try expectEq(@as(usize, 0), bench.total_operations);
    try expectEq(@as(usize, std.math.maxInt(u64)), bench.min_duration);
    try expectEq(@as(usize, 0), bench.max_duration);
    try expectEq(@as(usize, 0), bench.total_duration);
    try expectEq(@as(usize, 0), bench.durations.items.len);

    // These fields should stay the same however
    try expectEq(@as(usize, std.math.maxInt(u64)), bench.max_duration_limit);
    try expectEq(runs, bench.max_operations);

    // NOTE: Not sure why we need all these casts, but the compiler complains otherwise..
}

test "benchmark run with enum runner with init and run" {
    const runs: usize = 128;
    var bench = try Benchmark.init(std.math.maxInt(u64), runs, test_alloc);
    defer bench.deinit();

    const Runner = enum {
        const Self = @This();

        Variant,

        pub fn init(_: std.mem.Allocator) !Self {
            return Self.Variant;
        }
        pub fn run(_: *Self) void {}
    };

    const res = try bench.run(Runner, "test_bench");

    try expectEq(runs, res.total_operations);
}

test "benchmark run with struct runner with init, run and deinit" {
    const runs: usize = 128;
    var bench = try Benchmark.init(std.math.maxInt(u64), runs, test_alloc);
    defer bench.deinit();

    const Runner = struct {
        const Self = @This();
        var init_count: usize = 0;

        items: []u8,
        alloc: std.mem.Allocator,

        pub fn init(a: std.mem.Allocator) !Self {
            Self.init_count += 1;
            return Self{ .items = try a.alloc(u8, 5), .alloc = a };
        }
        pub fn run(self: Self) void {
            if (self.items[1] >= self.items[2]) {
                self.items[2] = self.items[3];
            } else {
                self.items[1] = self.items[4];
            }
        }

        pub fn deinit(self: Self) void {
            self.alloc.free(self.items);
        }
    };

    const res = try bench.run(Runner, "test_bench");

    try expectEq(runs, res.total_operations);

    // The runner should have been initialised as many times as there were runs, plus 1
    // NOTE: Although ideally it should be initialised exactly as many times as runs, it's
    // just the metaprogramming in `run` gets more akward if we try to make that happen
    try expectEq(runs + 1, Runner.init_count);
}

test "benchmark run with complete bench-runner struct" {
    const runs: usize = 128;
    var bench = try Benchmark.init(std.math.maxInt(u64), runs, test_alloc);
    defer bench.deinit();

    const Runner = struct {
        const Self = @This();
        var init_count: usize = 0;
        var reset_count: usize = 0;
        var deinit_count: usize = 0;

        items: []u64,
        alloc: std.mem.Allocator,

        pub fn init(a: std.mem.Allocator) !Self {
            Self.init_count += 1;
            return Self{ .items = try a.alloc(u64, 64), .alloc = a };
        }
        pub fn run(self: Self) void {
            for (self.items, 0..) |*item, i| {
                if (item.* <= i) item.* = i else item.* = 0;
            }
        }
        pub fn deinit(self: Self) void {
            Self.deinit_count += 1;
            self.alloc.free(self.items);
        }
        pub fn reset(self: Self) void {
            Self.reset_count += 1;
            @memset(self.items, 0);
        }
    };

    const res = try bench.run(Runner, "test_bench");
    try expectEq(runs, res.total_operations);

    // Since a reset function was provided the runner should only be inited once
    try expectEq(@as(usize, 1), Runner.init_count);

    // Since a reset function was provided the runner should only be destroyed once
    try expectEq(@as(usize, 1), Runner.deinit_count);

    // However it should have been reseted as many times as there are runs
    try expectEq(runs, Runner.reset_count);
}

test "benchmark quickSort" {
    comptime var nums = [_]u64{ 2, 3, 4, 6, 1, 8, 0, 5 };
    comptime Benchmark.quickSort(&nums, 0, nums.len - 1);

    try expectEq([_]u64{ 0, 1, 2, 3, 4, 5, 6, 8 }, nums);
}

// TODO: Add a test for Benchmark.calculatePercentiles

test "benchmark calculateAverage and calulateStd" {
    var bench = try Benchmark.init(std.math.maxInt(u64), 8, test_alloc);
    defer bench.deinit();

    try expectEq(@as(u64, 0), bench.calculateAverage());
    try expectEq(@as(u64, 0), bench.calculateStd());

    try bench.durations.append(0);
    try expectEq(@as(u64, 0), bench.calculateAverage());
    try expectEq(@as(u64, 0), bench.calculateStd());

    for (1..16) |i| try bench.durations.append(i);
    try expectEq(@as(u64, 7), bench.calculateAverage());
    try expectEq(@as(u64, 4), bench.calculateStd());

    for (16..101) |i| try bench.durations.append(i);
    try expectEq(@as(u64, 50), bench.calculateAverage());
    try expectEq(@as(u64, 29), bench.calculateStd());
}
