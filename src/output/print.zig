const std = @import("std");

// TODO : do we need a mutex here ?

pub fn prettyPrint(indent: usize, text: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    var lines = text.splitLines();
    while (lines.next()) |line| {
        // Indent the line by the specified amount.
        var spaces: [indent]u8 = undefined;
        for (spaces) |*space| space.* = ' ';
        try stdout.print("{}{}\n", .{ std.mem.sliceTo(&spaces, indent), line });
    }
}
