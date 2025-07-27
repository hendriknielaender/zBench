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
    const stdout = std.fs.File.stdout().deprecatedWriter();

    var bench = zbench.Benchmark.init(gpa.allocator(), .{
        .iterations = 64,
    });
    defer {
        bench.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.panic("Memory leak detected", .{});
    }

    try bench.add("My Benchmark 1", myBenchmark, .{});

    try bench.add("My Benchmark 2 (tracking)", myBenchmark, .{
        .track_allocations = true,
    });

    try bench.add("My Benchmark 3 (shuffling)", myBenchmark, .{
        .use_shuffling_allocator = true,
    });

    try bench.add("My Benchmark 4 (shuffling + track)", myBenchmark, .{
        .track_allocations = true,
        .use_shuffling_allocator = true,
    });

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
