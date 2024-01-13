const std = @import("std");
const test_alloc = std.testing.allocator;
const print = std.debug.print;
const expectEq = std.testing.expectEqual;

const Benchmark = @import("./zbench.zig").Benchmark;

test "Benchmark.calculateStd and Benchmark.calculateAverage" {
    var bench = try Benchmark.init(test_alloc);
    defer bench.durations.deinit();

    try expectEq(@as(u64, 0), bench.calculateAverage());
    try expectEq(@as(u64, 0), bench.calculateStd());

    try bench.durations.append(1);
    try expectEq(@as(u64, 1), bench.calculateAverage());
    try expectEq(@as(u64, 0), bench.calculateStd());

    for (1..16) |i| try bench.durations.append(i);
    try expectEq(@as(u64, 7), bench.calculateAverage());
    try expectEq(@as(u64, 4), bench.calculateStd());

    for (16..101) |i| try bench.durations.append(i);
    try expectEq(@as(u64, 50), bench.calculateAverage());
    try expectEq(@as(u64, 29), bench.calculateStd());

    bench.durations.clearRetainingCapacity();
    for (0..10) |_| try bench.durations.append(1);

    try expectEq(@as(u64, 1), bench.calculateAverage());
    try expectEq(@as(u64, 0), bench.calculateStd());
}

test "Benchmark.run with standalone function" {
    const run_args = Benchmark.RunArgs{ .max_runs = 1000, .max_time = std.math.maxInt(u64) };
    var bench = try Benchmark.init(test_alloc);
    defer bench.durations.deinit();

    const Nested = struct {
        pub fn run1(_: std.mem.Allocator) void {}
        pub fn run2(_: *Benchmark) void {}
    };

    const res = try bench.runSingle(Nested.run1, run_args);
    bench.reset();

    // We set no time-limit, so it should perform all the runs requested
    try expectEq(run_args.max_runs, res.total_runs);

    // We also expect the Benchmark instance to be reset
    try expectEq(@as(usize, 0), bench.total_runs);
    try expectEq(@as(usize, std.math.maxInt(u64)), bench.min_duration);
    try expectEq(@as(usize, 0), bench.max_duration);
    try expectEq(@as(usize, 0), bench.total_duration);
    try expectEq(@as(usize, 0), bench.durations.items.len);

    // Make sure all runner-signatures are valid
    _ = try bench.runSingle(Nested.run2, run_args);
}

test "Benchmark.run with enum runner with init and run" {
    const run_args = Benchmark.RunArgs{ .max_runs = 1000, .max_time = std.math.maxInt(u64) };
    var bench = try Benchmark.init(test_alloc);
    defer bench.durations.deinit();

    const Runner = enum {
        const Self = @This();

        Variant,

        pub fn init(_: std.mem.Allocator) !Self {
            return Self.Variant;
        }
        pub fn run(_: *Self) void {}
    };

    const res = try bench.runSingle(Runner, run_args);

    try expectEq(run_args.max_runs, res.total_runs);
}

test "Benchmark.run with struct runner with init, run and deinit" {
    const run_args = Benchmark.RunArgs{ .max_runs = 1000, .max_time = std.math.maxInt(u64) };
    var bench = try Benchmark.init(test_alloc);
    defer bench.durations.deinit();

    const Runner = struct {
        const Self = @This();
        var init_count: usize = 0;
        var deinit_count: usize = 0;

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
            Self.deinit_count += 1;
            self.alloc.free(self.items);
        }
    };

    const res = try bench.runSingle(Runner, run_args);

    try expectEq(run_args.max_runs, res.total_runs);

    // The runner should have been initialised as many times as it got deinitialised
    try expectEq(Runner.init_count, Runner.deinit_count);

    // The runner should have been initialised as many times as max_runs + max_runs / 32 + 1
    // FIXME: (The +1 is due to us initializing at the very end of the bench-loop despite not using
    // the runner afterwards..
    try expectEq(Runner.init_count, 33 * run_args.max_runs / 32 + 1);
}

test "Benchmark.run with complete bench-runner struct" {
    const run_args = Benchmark.RunArgs{ .max_runs = 1000, .max_time = std.math.maxInt(u64) };
    var bench = try Benchmark.init(test_alloc);
    defer bench.durations.deinit();

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

    const res = try bench.runSingle(Runner, run_args);
    try expectEq(run_args.max_runs, res.total_runs);

    // Since a reset function was provided the runner should only be inited once
    try expectEq(@as(usize, 1), Runner.init_count);

    // Since a reset function was provided the runner should only be deinited once
    try expectEq(@as(usize, 1), Runner.deinit_count);

    // However it should have been reseted as many times as there are runs minus the trial-runs
    try expectEq(run_args.max_runs, Runner.reset_count - run_args.max_runs / 32);
}

test "Benchmark.quickSort" {
    comptime var nums = [_]u64{ 2, 3, 4, 6, 1, 8, 0, 5 };
    comptime Benchmark.quickSort(&nums, 0, nums.len - 1);

    try expectEq([_]u64{ 0, 1, 2, 3, 4, 5, 6, 8 }, nums);
}

// TODO: Add a test for Benchmark.calculatePercentiles
