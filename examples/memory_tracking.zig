const std = @import("std");
const zbench = @import("zbench");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};

fn myBenchmark(allocator: std.mem.Allocator) void {
    for (0..2000) |_| {
        const buf = allocator.alloc(u8, 512) catch @panic("OOM");
        defer allocator.free(buf);
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(gpa.allocator(), .{
        .iterations = 64,
    });
    defer {
        bench.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.panic("Memory leak detected", .{});
    }

    try bench.add("My Benchmark 1", myBenchmark, .{});
    try bench.add("My Benchmark 2", myBenchmark, .{
        .track_allocations = true,
    });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
