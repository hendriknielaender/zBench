const std = @import("std");
const format = @import("./format.zig");

test "duration" {
    _ = std.testing.allocator;

    var buffer: [128]u8 = undefined;

    {
        const result = try format.duration(buffer[0..], 1);
        try std.testing.expectEqualSlices(u8, "1ns", result);
    }

    {
        const result = try format.duration(buffer[0..], 999);
        try std.testing.expectEqualSlices(u8, "999ns", result);
    }

    {
        const result = try format.duration(buffer[0..], 1000);
        try std.testing.expectEqualSlices(u8, "1.000µs", result);
    }

    {
        const result = try format.duration(buffer[0..], 1000000);
        try std.testing.expectEqualSlices(u8, "1.000ms", result);
    }

    {
        const result = try format.duration(buffer[0..], 1000000000);
        try std.testing.expectEqualSlices(u8, "1.000s", result);
    }

    {
        const result = try format.duration(buffer[0..], 1234567890);
        try std.testing.expectEqualSlices(u8, "1.235s", result);
    }

    {
        const result = try format.duration(buffer[0..], 1023456789);
        try std.testing.expectEqualSlices(u8, "1.023s", result);
    }

    {
        const result = try format.duration(buffer[0..], 1999999999);
        try std.testing.expectEqualSlices(u8, "2.000s", result);
    }

    {
        const result = try format.duration(buffer[0..], 1500);
        try std.testing.expectEqualSlices(u8, "1.500µs", result);
    }
}
