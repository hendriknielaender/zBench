const std = @import("std");
const zbench = @import("zbench");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n\n{}\n", .{try zbench.getSystemInfo()});
}
