const std = @import("std");
const zbench = @import("zbench");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

fn myBenchmark(alloc: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..2_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
        const buf = alloc.alloc(u8, 1024) catch unreachable;
        defer alloc.free(buf);
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var bench = zbench.Benchmark.init(gpa.allocator(), .{});
    defer {
        bench.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.panic("Memory leak detected", .{});
    }

    try bench.add("My Benchmark 1", myBenchmark, .{
        .iterations = 10,
        .track_allocations = false,
    });
    try bench.add("My Benchmark 2", myBenchmark, .{
        .iterations = 10,
        .track_allocations = true,
    });

    try stdout.writeAll("[");
    var iter = try bench.iterator();
    var i: usize = 0;
    while (try iter.next()) |step| switch (step) {
        .progress => |_| {},
        .result => |x| {
            defer x.deinit();
            defer i += 1;
            if (0 < i) try stdout.writeAll(", ");
            try x.writeJSON(gpa.allocator(), stdout);
        },
    };
    try stdout.writeAll("]\n");
}
