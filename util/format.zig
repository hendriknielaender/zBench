const std = @import("std");

pub fn duration(buffer: []u8, d: u64) ![]u8 {
    const units = [_][]const u8{ "ns", "µs", "ms", "s" };

    var scaledDuration: u64 = d;
    var unitIndex: usize = 0;

    var fractionalPart: u64 = 0;

    while (scaledDuration >= 1_000 and unitIndex < units.len - 1) {
        fractionalPart = scaledDuration % 1_000;
        scaledDuration /= 1_000;
        unitIndex += 1;
    }

    const formatted = try std.fmt.bufPrint(buffer, "{d}.{d}{s}", .{ scaledDuration, fractionalPart, units[unitIndex] });

    return formatted;
}
