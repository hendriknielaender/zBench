const std = @import("std");
const zbench = @import("zbench");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var stdout: std.Io.File.Writer = std.Io.File.stdout().writerStreaming(io, &.{});
    const writer = &stdout.interface;

    try writer.print("\n\n{f}\n", .{try zbench.getSystemInfo()});
}
