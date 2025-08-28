const std = @import("std");
const zbench = @import("zbench");

fn sleepBenchmark(_: std.mem.Allocator) void {
    std.Thread.sleep(100_000_000);
}

pub fn main() !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const writer = &stdout_writer.interface;

    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();
    try bench.add("Sleep Benchmark", sleepBenchmark, .{});

    try writer.writeAll("\n");
    try bench.run(writer);
    try writer.flush();
}
