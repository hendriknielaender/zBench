const std = @import("std");
const zbench = @import("zbench");
var gpa = std.heap.DebugAllocator(.{}){};

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
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const stdout: std.Io.File = .stdout();
    var filewriter: std.Io.File.Writer = stdout.writerStreaming(io, &.{});
    const writer: *std.Io.Writer = &filewriter.interface;

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

    try writer.writeAll("[");
    var iter = try bench.iterator();
    var i: usize = 0;
    while (try iter.next(io)) |step| switch (step) {
        .progress => {},
        .result => |x| {
            defer x.deinit();
            defer i += 1;
            if (0 < i) try writer.writeAll(", ");
            try x.writeJSON(writer);
        },
    };
    try writer.writeAll("]\n");
}
