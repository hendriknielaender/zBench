// setColor function was taken (and modified) from the Zig 0.16-dev
// standard library, <https://codeberg.org/ziglang/zig/src/commit/312b231da9a90e477c56801fb2056324edc50ea1/lib/std/Io/Terminal.zig>.
// Copyright (c) Zig contributors.

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
        // TODO : Windows variant only works with Io.File...
        else => {
            return SetColorError;
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
