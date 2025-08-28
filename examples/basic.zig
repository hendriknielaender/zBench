const std = @import("std");
const zbench = @import("zbench");

fn myBenchmark(allocator: std.mem.Allocator) void {
    for (0..1000) |_| {
        const buf = allocator.alloc(u8, 512) catch @panic("Out of memory");
        defer allocator.free(buf);
    }
}

pub fn main() !void {
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const writer = &stdout_writer.interface;

    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark", myBenchmark, .{});

    try writer.writeAll("\n");
    try bench.run(writer);
    try writer.flush();
}
