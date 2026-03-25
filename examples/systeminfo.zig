const std = @import("std");
const zbench = @import("zbench");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const stdout: std.Io.File = .stdout();
    var filewriter: std.Io.File.Writer = stdout.writerStreaming(io, &.{});
    const writer: *std.Io.Writer = &filewriter.interface;

    try writer.print("\n\n{f}\n", .{try zbench.getSystemInfo()});
}
