const std = @import("std");
const zbench = @import("zbench");

fn myBenchmark(allocator: std.mem.Allocator) void {
    for (0..2000) |_| {
        const buf = allocator.alloc(u8, 512) catch @panic("OOM");
        defer allocator.free(buf);
    }
}

test "bench test memory tracking" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.testing.allocator, .{
        .iterations = 64,
    });
    defer bench.deinit();

    try bench.add("My Benchmark 1", myBenchmark, .{});
    try bench.add("My Benchmark 2", myBenchmark, .{
        .track_allocations = true,
    });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
