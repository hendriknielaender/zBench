const std = @import("std");
const time = std.time;

pub fn benchmark(func: anytype, func_name: []const u8) void {
    const start = time.milliTimestamp();
    func();
    const end = time.milliTimestamp();
    const elapsed = end - start;

    var stdout = std.io.getStdOut().writer();
    _ = stdout.print("{s}: Elapsed time: {d} ms\n", .{ func_name, elapsed }) catch {};
}
