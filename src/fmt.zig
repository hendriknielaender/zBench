// setColor function was taken (and modified) from the Zig 0.16-dev
// standard library. Copyright (c) Zig contributors.
//
const std = @import("std");
const Mode = std.Io.Terminal.Mode;
const Color = std.Io.Terminal.Color;
const SetColorError = std.Io.Terminal.SetColorError;

pub fn setColor(mode: Mode, writer: *std.Io.Writer, color: Color) SetColorError!void {
    switch (mode) {
        .no_color => return,
        .escape_codes => {
            const color_string = switch (color) {
                .black => "\x1b[30m",
                .red => "\x1b[31m",
                .green => "\x1b[32m",
                .yellow => "\x1b[33m",
                .blue => "\x1b[34m",
                .magenta => "\x1b[35m",
                .cyan => "\x1b[36m",
                .white => "\x1b[37m",
                .bright_black => "\x1b[90m",
                .bright_red => "\x1b[91m",
                .bright_green => "\x1b[92m",
                .bright_yellow => "\x1b[93m",
                .bright_blue => "\x1b[94m",
                .bright_magenta => "\x1b[95m",
                .bright_cyan => "\x1b[96m",
                .bright_white => "\x1b[97m",
                .bold => "\x1b[1m",
                .dim => "\x1b[2m",
                .reset => "\x1b[0m",
            };
            try writer.writeAll(color_string);
        },
        .windows_api => |wa| {
            const windows = std.os.windows;
            const attributes: windows.WORD = switch (color) {
                .black => 0,
                .red => windows.FOREGROUND_RED,
                .green => windows.FOREGROUND_GREEN,
                .yellow => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN,
                .blue => windows.FOREGROUND_BLUE,
                .magenta => windows.FOREGROUND_RED | windows.FOREGROUND_BLUE,
                .cyan => windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE,
                .white => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE,
                .bright_black => windows.FOREGROUND_INTENSITY,
                .bright_red => windows.FOREGROUND_RED | windows.FOREGROUND_INTENSITY,
                .bright_green => windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY,
                .bright_yellow => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_INTENSITY,
                .bright_blue => windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                .bright_magenta => windows.FOREGROUND_RED | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                .bright_cyan => windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                .bright_white, .bold => windows.FOREGROUND_RED | windows.FOREGROUND_GREEN | windows.FOREGROUND_BLUE | windows.FOREGROUND_INTENSITY,
                // "dim" is not supported using basic character attributes, but let's still make it do *something*.
                // This matches the old behavior of TTY.Color before the bright variants were added.
                .dim => windows.FOREGROUND_INTENSITY,
                .reset => wa.reset_attributes,
            };
            try writer.flush();
            try windows.SetConsoleTextAttribute(wa.handle, attributes);
        },
    }
}
fn FormatJSONArrayData(comptime T: type) type {
    return struct {
        values: []const T,

        const Self = @This();

        fn format(
            data: Self,
            writer: *std.Io.Writer,
        ) !void {
            try writer.writeAll("[");
            for (data.values, 0..) |x, i| {
                if (0 < i) try writer.writeAll(", ");
                try writer.print("{}", .{x});
            }
            try writer.writeAll("]");
        }
    };
}

pub fn formatJSONArray(
    comptime T: type,
    values: []const T,
) std.fmt.Alt(FormatJSONArrayData(T), FormatJSONArrayData(T).format) {
    const data = FormatJSONArrayData(T){ .values = values };
    return .{ .data = data };
}
