const std = @import("std");
const Color = @import("./color.zig").Color;

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

/// Pretty-prints the header for the result pretty-print table
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintHeader(writer: anytype) !void {
    try writer.print(
        "\n{s:<22} {s:<8} {s:<14} {s:<22} {s:<28} {s:<10} {s:<10} {s:<10}\n",
        .{ "benchmark", "runs", "total time", "time/run (avg ± σ)", "(min ... max)", "p75", "p99", "p995" },
    );
    try writer.print("-----------------------------------------------------------------------------------------------------------------------------\n", .{});
}

/// Pretty-prints the name of the benchmark
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintName(name: []const u8, writer: anytype, color: Color) !void {
    try writer.print("{s}{s:<22}{s} ", .{ color.code(), name, Color.reset.code() });
}

/// Pretty-prints the number of total operations (or runs) of the benchmark performed
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintTotalOperations(total_operations: u64, writer: anytype, color: Color) !void {
    try writer.print("{s}{d:<8}{s} ", .{ color.code(), total_operations, Color.reset.code() });
}

/// Pretty-prints the total time it took to perform all the runs
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintTotalTime(total_time: u64, writer: anytype, color: Color) !void {
    var buffer: [128]u8 = undefined;
    const str = try duration(buffer[0..], total_time);

    try writer.print("{s}{s:<14}{s} ", .{ color.code(), str, Color.reset.code() });
}

/// Pretty-prints the average (arithmetic mean) and the standard deviation of the durations
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintAvgStd(avg: u64, stdd: u64, writer: anytype, color: Color) !void {
    var buffer: [128]u8 = undefined;
    var avg_stdd_offset = (try duration(buffer[0..], avg)).len;
    avg_stdd_offset += (try std.fmt.bufPrint(buffer[avg_stdd_offset..], " ± ", .{})).len;
    avg_stdd_offset += (try duration(buffer[avg_stdd_offset..], stdd)).len;
    const str = buffer[0..avg_stdd_offset];

    try writer.print("{s}{s:<22}{s} ", .{ color.code(), str, Color.reset.code() });
}

/// Pretty-prints the minumim and maximum duration
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintMinMax(min: u64, max: u64, writer: anytype, color: Color) !void {
    var min_buffer: [128]u8 = undefined;
    const min_str = try duration(min_buffer[0..], min);

    var max_buffer: [128]u8 = undefined;
    const max_str = try duration(max_buffer[0..], max);

    var buffer: [128]u8 = undefined;
    const str = try std.fmt.bufPrint(buffer[0..], "({s} ... {s})", .{ min_str, max_str });

    try writer.print("{s}{s:<28}{s} ", .{ color.code(), str, Color.reset.code() });
}

/// Pretty-prints the 75th, 99th and 99.5th percentile of the durations
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintPercentiles(p75: u64, p99: u64, p995: u64, writer: anytype, color: Color) !void {
    var p75_buffer: [128]u8 = undefined;
    const p75_str = try duration(p75_buffer[0..], p75);

    var p99_buffer: [128]u8 = undefined;
    const p99_str = try duration(p99_buffer[0..], p99);

    var p995_buffer: [128]u8 = undefined;
    const p995_str = try duration(p995_buffer[0..], p995);

    try writer.print("{s}{s:<10} {s:<10} {s:<10}{s} ", .{ color.code(), p75_str, p99_str, p995_str, Color.reset.code() });
}
