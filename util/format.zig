const std = @import("std");
const log = std.log.scoped(.zbench_format);

pub fn memorySize(bytes: u64, allocator: std.mem.Allocator) ![]const u8 {
    const units = .{ "B", "KB", "MB", "GB", "TB" };
    var size: f64 = @floatFromInt(bytes);
    var unit_index: usize = 0;

    while (size >= 1024 and unit_index < units.len - 1) : (unit_index += 1) {
        size /= 1024;
    }

    const unit = switch (unit_index) {
        0 => "B",
        1 => "KB",
        2 => "MB",
        3 => "GB",
        4 => "TB",
        5 => "PB",
        6 => "EB",
        else => unreachable,
    };

    // Format the result with two decimal places if needed
    var buf: [64]u8 = undefined; // Buffer for formatting
    const formattedSize = try std.fmt.bufPrint(&buf, "{d:.2} {s}", .{ size, unit });
    return allocator.dupe(u8, formattedSize);
}

/// Pretty-prints the header for the result pretty-print table
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintHeader(writer: anytype) !void {
    try writer.print(
        "\n{s:<22} {s:<8} {s:<14} {s:<22} {s:<28} {s:<10} {s:<10} {s:<10}\n",
        .{
            "benchmark",
            "runs",
            "total time",
            "time/run (avg ± σ)",
            "(min ... max)",
            "p75",
            "p99",
            "p995",
        },
    );
    const dashes = "-------------------------";
    try writer.print(dashes ++ dashes ++ dashes ++ dashes ++ dashes ++ "\n", .{});
}

/// Pretty-prints the name of the benchmark
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintName(name: []const u8, writer: anytype) !void {
    try writer.print("{s:<22} ", .{name});
}

/// Pretty-prints the number of total operations (or runs) of the benchmark performed
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintTotalOperations(total_operations: u64, writer: anytype) !void {
    try writer.print("{d:<8} ", .{total_operations});
}

/// Pretty-prints the total time it took to perform all the runs
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintTotalTime(total_time: u64, writer: anytype) !void {
    try writer.print("{s:<14} ", .{std.fmt.fmtDuration(total_time)});
}

/// Pretty-prints the average (arithmetic mean) and the standard deviation of the durations
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintAvgStd(avg: u64, stddev: u64, writer: anytype) !void {
    var buffer: [128]u8 = undefined;
    const str = try std.fmt.bufPrint(&buffer, "{} ± {}", .{
        std.fmt.fmtDuration(avg),
        std.fmt.fmtDuration(stddev),
    });
    try writer.print("{s:<22} ", .{str});
}

/// Pretty-prints the minumim and maximum duration
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintMinMax(min: u64, max: u64, writer: anytype) !void {
    var buffer: [128]u8 = undefined;
    const str = try std.fmt.bufPrint(&buffer, "({} ... {})", .{
        std.fmt.fmtDuration(min),
        std.fmt.fmtDuration(max),
    });
    try writer.print("{s:<28} ", .{str});
}

/// Pretty-prints the 75th, 99th and 99.5th percentile of the durations
/// writer: Type that has the associated method print (for example std.io.getStdOut.writer())
pub fn prettyPrintPercentiles(p75: u64, p99: u64, p995: u64, writer: anytype) !void {
    try writer.print("{s:<10} {s:<10} {s:<10}", .{
        std.fmt.fmtDuration(p75),
        std.fmt.fmtDuration(p99),
        std.fmt.fmtDuration(p995),
    });
}
