const std = @import("std");
const zbench = @import("zbench");

fn myBenchmark(allocator: std.mem.Allocator) void {
    for (0..1000) |_| {
        const buf = allocator.alloc(u8, 512) catch @panic("Out of memory");
        defer allocator.free(buf);
    }
}

test "bench test basic" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.testing.allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark", myBenchmark, .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
