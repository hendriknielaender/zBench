const std = @import("std");
const zbench = @import("zbench");

test "system info" {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\n\n{}\n", .{try zbench.getSystemInfo()});
}
