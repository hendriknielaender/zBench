const std = @import("std");
const zbench = @import("zbench");

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    try stdout.print("\n\n{f}\n", .{try zbench.getSystemInfo()});
}
