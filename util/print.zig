const std = @import("std");

// TODO : do we need a mutex here ?

pub fn prettyPrint(comptime indent: usize, text: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    var lines = std.mem.splitSequence(u8, text, "\n");
    while (lines.next()) |line| {
        // Indent the line by the specified amount.
        try stdout.print(
            "{s}{s}\n",
            .{ std.mem.sliceTo(&[_]u8{' '} ** indent, indent), line },
        );
    }
}
