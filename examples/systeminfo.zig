const std = @import("std");
const zbench = @import("zbench");

pub fn main() !void {
    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    const writer = &stdout.interface;
    try writer.print("\n\n{f}\n", .{try zbench.getSystemInfo()});
}
