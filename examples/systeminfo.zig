const std = @import("std");
const zbench = @import("zbench");

pub fn main() !void {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    var stdout: std.Io.File.Writer = std.Io.File.stdout().writerStreaming(io, &.{});
    const writer = &stdout.interface;

    try writer.print("\n\n{f}\n", .{try zbench.getSystemInfo()});
}
