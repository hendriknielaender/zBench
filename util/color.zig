const std = @import("std");

pub const Color = enum {
    black,
    grey,
    red,
    red_bright,
    green,
    green_bright,
    yellow,
    yellow_bright,
    blue,
    blue_bright,
    magenta,
    magenta_bright,
    cyan,
    cyan_bright,
    reset,
    default,

    // Return the ANSI escape code for this color.
    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .black => "\x1b[30m",
            .grey => "\x1b[90m", // this is actually 'bright black'
            .red => "\x1b[31m",
            .red_bright => "\x1b[91m",
            .green => "\x1b[32m",
            .green_bright => "\x1b[92m",
            .yellow => "\x1b[33m",
            .yellow_bright => "\x1b[93m",
            .blue => "\x1b[34m",
            .blue_bright => "\x1b[94m",
            .magenta => "\x1b[35m",
            .magenta_bright => "\x1b[95m",
            .cyan => "\x1b[36m",
            .cyan_bright => "\x1b[96m",
            .reset => "\x1b[0m",
            .default => "",
        };
    }
};
