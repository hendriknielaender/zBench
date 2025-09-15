const std = @import("std");

pub const Color = std.Io.tty.Color;

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
