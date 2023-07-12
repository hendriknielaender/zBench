const std = @import("std");

pub const Color = enum {
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    reset,

    // Return the ANSI escape code for this color.
    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .reset => "\x1b[0m",
        };
    }
};

pub fn colorPrint(color: Color, text: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{}{}{}", .{ color.code(), text, Color.reset.code() });
}
