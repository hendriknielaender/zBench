const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn myBenchmark(alloc: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..2_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
        const buf = alloc.alloc(u8, 1024) catch unreachable;
        defer alloc.free(buf);
    }
}

test "bench test json" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(test_allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark 1", myBenchmark, .{ .iterations = 10 });

    try stdout.writeAll("[");
    var iter = try bench.iterator();
    var i: usize = 0;
    while (try iter.next()) |step| switch (step) {
        .progress => |_| {},
        .result => |x| {
            defer x.deinit();
            defer i += 1;
            if (0 < i) try stdout.writeAll(", ");
            try x.writeJSON(stdout);
        },
    };
    try stdout.writeAll("]\n");
}
