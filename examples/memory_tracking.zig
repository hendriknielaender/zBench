const std = @import("std");
const zbench = @import("zbench");

// amount of memory that should appear in the [MEMORY] section of the output
const NUM_BYTES = 1024;

fn myBenchmark(allocator: std.mem.Allocator) void {
    for (0..2000) |_| {
        const buf = allocator.alloc(u8, NUM_BYTES) catch @panic("OOM");
        defer allocator.free(buf);
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const stdout: std.Io.File = .stdout();

    var bench = zbench.Benchmark.init(init.gpa, .{
        .iterations = 64,
    });
    defer bench.deinit();

    try bench.add("My Benchmark 1", myBenchmark, .{});
    try bench.add("My Benchmark 2", myBenchmark, .{ .track_allocations = true });
    try bench.run(io, stdout);
}
