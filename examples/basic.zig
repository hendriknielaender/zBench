const std = @import("std");
const zbench = @import("zbench");

fn myBenchmark(allocator: std.mem.Allocator) void {
    for (0..1000) |_| {
        const buf = allocator.alloc(u8, 512) catch @panic("Out of memory");
        defer allocator.free(buf);
    }
}

pub fn main() !void {
    var stdout = std.fs.File.stdout().writer(&.{});
    var writer = &stdout.interface;

    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark", myBenchmark, .{});

    try writer.writeAll("\n");
    try bench.run(writer);
}
