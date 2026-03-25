const std = @import("std");
const zbench = @import("zbench");

fn myBenchmark(allocator: std.mem.Allocator) void {
    for (0..2000) |_| {
        const buf = allocator.alloc(u8, 512) catch @panic("OOM");
        defer allocator.free(buf);
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const stdout: std.Io.File = .stdout();

    var bench = zbench.Benchmark.init(init.gpa, .{ .iterations = 64 });
    defer bench.deinit();

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
    try bench.run(io, stdout);
}
