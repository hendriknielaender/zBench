const std = @import("std");
const test_alloc = std.testing.allocator;
const print = std.debug.print;
const expectEq = std.testing.expectEqual;
const expectEqDeep = std.testing.expectEqualDeep;

const Benchmark = @import("./zbench.zig").Benchmark;

test "Benchmark.calculateStd and Benchmark.calculateAverage" {
    var bench = try Benchmark.init("test_bench", std.testing.allocator, .{});
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

test "Benchmark.calculatePercentiles" {
    const P = Benchmark.Percentiles;
    var bench = try Benchmark.init("test_bench", std.testing.allocator, .{});
    defer bench.durations.deinit();

    for (0..100) |i| try bench.durations.append(i);
    try expectEq(
        P{ .p75 = 75, .p99 = 99, .p995 = 99 },
        bench.calculatePercentiles(),
    );

    std.mem.reverse(u64, bench.durations.items);
    try expectEq(
        P{ .p75 = 75, .p99 = 99, .p995 = 99 },
        bench.calculatePercentiles(),
    );
}
