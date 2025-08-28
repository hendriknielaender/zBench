const std = @import("std");
const zbench = @import("zbench");

pub fn main() !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const writer = &stdout_writer.interface;
    try writer.print("\n\n{f}\n", .{try zbench.getSystemInfo()});
    try writer.flush();
}
