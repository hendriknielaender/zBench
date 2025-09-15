const std = @import("std");

pub const Color = enum {
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    reset,
    none,

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
            .none => "",
        };
    }
};

fn FormatJSONArrayData(comptime T: type) type {
    return struct {
        values: []const T,

        const Self = @This();

        fn format(
            data: Self,
            writer: *std.io.Writer,
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
