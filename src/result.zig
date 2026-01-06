const std = @import("std");
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;

const Color = std.Io.Terminal.Color;
const Statistics = @import("statistics.zig").Statistics;
const fmt = @import("fmt.zig");
const statistics = @import("statistics.zig");
const Runner = @import("runner.zig");
const Readings = Runner.Readings;

/// Carries the results of a benchmark. The benchmark name and the recorded
/// durations are available, and some basic statistics are automatically
/// calculated.
pub const Result = struct {
    name: []const u8,
    readings: Readings,
    // TODO : make this configurable (#137)
    // TODO : make this work on Windows (#137)
    pprint_mode: std.Io.Terminal.Mode = .escape_codes,

    pub fn init(name: []const u8, readings: Runner.Readings) Result {
        return Result{ .name = name, .readings = readings };
    }

    pub fn deinit(self: Result) void {
        self.readings.deinit();
    }

    /// Formats and prints the benchmark result in a human readable format.
    /// writer: Type that has the associated method print (for example std.Io.getStdOut.writer())
    /// tty_config: TTY configuration for color output.
    pub fn prettyPrint(
        self: Result,
        writer: *std.Io.Writer,
    ) !void {
        var buf: [128]u8 = undefined;

        const timings_ns = self.readings.timings_ns;
        const s = try Statistics(u64).init(timings_ns);
        const truncated_name = self.name[0..@min(22, self.name.len)];
        // Benchmark name, number of iterations, and total time
        try writer.print("{s:<22} ", .{truncated_name});
        try fmt.setColor(self.pprint_mode, writer, Color.cyan);
        try writer.print("{d:<8} {D:<15}", .{
            self.readings.iterations,
            s.total,
        });
        // Mean + standard deviation
        try fmt.setColor(self.pprint_mode, writer, Color.green);
        try writer.print("{s:<23}", .{
            try std.fmt.bufPrint(&buf, "{D:.3} ± {D:.3}", .{
                s.mean,
                s.stddev,
            }),
        });
        // Minimum and maximum
        try fmt.setColor(self.pprint_mode, writer, Color.blue);
        try writer.print("{s:<29}", .{
            try std.fmt.bufPrint(&buf, "({D:.3} ... {D:.3})", .{
                s.min,
                s.max,
            }),
        });
        // Percentiles
        try fmt.setColor(self.pprint_mode, writer, Color.cyan);
        try writer.print("{D:<10} {D:<10} {D:<10}", .{
            s.percentiles.p75,
            s.percentiles.p99,
            s.percentiles.p995,
        });
        // End of line
        try fmt.setColor(self.pprint_mode, writer, Color.reset);
        try writer.writeAll("\n");

        if (self.readings.allocations) |allocs| {
            const m = try Statistics(usize).init(allocs.maxes);
            // Benchmark name
            const name = try std.fmt.bufPrint(&buf, "{s} [MEMORY]", .{
                truncated_name,
            });
            try writer.print("{s:<46} ", .{name});
            // Mean + standard deviation
            try fmt.setColor(self.pprint_mode, writer, Color.green);
            try writer.print("{s:<23}", .{
                try std.fmt.bufPrint(&buf, "{Bi:.3} ± {Bi:.3}", .{
                    m.mean,
                    m.stddev,
                }),
            });
            // Minimum and maximum
            try fmt.setColor(self.pprint_mode, writer, Color.blue);
            try writer.print("{s:<29}", .{
                try std.fmt.bufPrint(&buf, "({Bi:.3} ... {Bi:.3})", .{
                    m.min,
                    m.max,
                }),
            });
            // Percentiles
            try fmt.setColor(self.pprint_mode, writer, Color.cyan);
            try writer.print("{Bi:<10.3} {Bi:<10.3} {Bi:<10.3}", .{
                m.percentiles.p75,
                m.percentiles.p99,
                m.percentiles.p995,
            });
            // End of line
            try fmt.setColor(self.pprint_mode, writer, Color.reset);
            try writer.writeAll("\n");
        }
    }

    pub fn writeJSON(
        self: Result,
        writer: *std.Io.Writer,
    ) !void {
        const timings_ns_stats =
            try Statistics(u64).init(self.readings.timings_ns);
        if (self.readings.allocations) |allocs| {
            const allocation_maxes_stats =
                try Statistics(usize).init(allocs.maxes);
            try writer.print(
                \\{{ "name": "{f}",
                \\   "timing_statistics": {f}, "timings": {f},
                \\   "max_allocation_statistics": {f}, "max_allocations": {f} }}
            ,
                .{
                    std.ascii.hexEscape(self.name, .lower),
                    statistics.fmtJSON(u64, "nanoseconds", timings_ns_stats),
                    fmt.formatJSONArray(u64, self.readings.timings_ns),
                    statistics.fmtJSON(usize, "bytes", allocation_maxes_stats),
                    fmt.formatJSONArray(usize, allocs.maxes),
                },
            );
        } else {
            try writer.print(
                \\{{ "name": "{f}",
                \\   "timing_statistics": {f}, "timings": {f} }}
            ,
                .{
                    std.ascii.hexEscape(self.name, .lower),
                    statistics.fmtJSON(u64, "nanoseconds", timings_ns_stats),
                    fmt.formatJSONArray(u64, self.readings.timings_ns),
                },
            );
        }
    }
};
