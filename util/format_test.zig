const std = @import("std");
const format = @import("./format.zig");

test "duration" {
    _ = std.testing.allocator;

    var buffer: [128]u8 = undefined;

    {
        const result = try format.duration(buffer[0..], 1);
        try std.testing.expectEqualSlices(u8, "1.0ns", result);
    }

    {
        const result = try format.duration(buffer[0..], 999);
        try std.testing.expectEqualSlices(u8, "999.0ns", result);
    }

    {
        const result = try format.duration(buffer[0..], 1000);
        try std.testing.expectEqualSlices(u8, "1.0µs", result);
    }

    {
        const result = try format.duration(buffer[0..], 1000000);
        try std.testing.expectEqualSlices(u8, "1.0ms", result);
    }

    {
        const result = try format.duration(buffer[0..], 1000000000);
        try std.testing.expectEqualSlices(u8, "1.0s", result);
    }

    {
        const result = try format.duration(buffer[0..], 1500);
        try std.testing.expectEqualSlices(u8, "1.500µs", result);
    }
}
