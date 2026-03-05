const std = @import("std");
const Terminal = std.Io.Terminal;
const Color = Terminal.Color;
const Duration = std.Io.Duration;
const assert = std.debug.assert;

const fmt = @import("fmt.zig");
const statistics = @import("statistics.zig");
const Runner = @import("runner.zig");
const Readings = Runner.Readings;
const Statistics = statistics.Statistics;
const MAX_NAME_LEN = @import("zbench.zig").MAX_NAME_LEN;

/// Carries the results of a benchmark. The benchmark name and the recorded
/// durations are available, and some basic statistics are automatically
/// calculated.
pub const Result = struct {
    name: []const u8,
    readings: Readings,

    pub fn init(name: []const u8, readings: Runner.Readings) Result {
        return Result{ .name = name, .readings = readings };
    }

    pub fn deinit(self: Result) void {
        self.readings.deinit();
    }

    /// Formats and prints the benchmark result in a human readable format.
    pub fn prettyPrint(
        self: Result,
        io: std.Io,
        file: std.Io.File,
        name_len: usize,
    ) !void {
        var w: std.Io.File.Writer = file.writerStreaming(io, &.{});
        const writer: *std.Io.Writer = &w.interface;
        const terminal_mode: Terminal.Mode = try .detect(io, file, false, false);
        const terminal: Terminal = .{ .writer = writer, .mode = terminal_mode };

        const buf_len: usize = 128;
        const _name_len = if (name_len > MAX_NAME_LEN) MAX_NAME_LEN else name_len;
        assert(_name_len + 3 <= buf_len);

        var buf: [buf_len]u8 = undefined;

        const timings_ns = self.readings.timings_ns;
        const s = try Statistics(u64).init(timings_ns);
        const truncated_name = self.name[0..@min(MAX_NAME_LEN, self.name.len)];

        // Benchmark name, number of iterations, and total time
        _ = try std.Io.Writer.alignBuffer(writer, truncated_name, _name_len + 3, .left, ' ');
        try terminal.setColor(Color.cyan);
        var tmp = try std.fmt.bufPrint(&buf, "{d:<8} {f}", .{
            self.readings.iterations,
            Duration.fromNanoseconds(s.total),
        });
        _ = try std.Io.Writer.alignBuffer(writer, tmp, 24, .left, ' ');

        // Mean + standard deviation
        try terminal.setColor(Color.green);
        tmp = try std.fmt.bufPrint(&buf, "{f} ± {f}", .{
            Duration.fromNanoseconds(s.mean),
            Duration.fromNanoseconds(s.stddev),
        });
        _ = try std.Io.Writer.alignBuffer(writer, tmp, 23, .left, ' ');

        // Minimum and maximum
        try terminal.setColor(Color.green);
        tmp = try std.fmt.bufPrint(&buf, "({f} ... {f})", .{
            Duration.fromNanoseconds(s.min),
            Duration.fromNanoseconds(s.max),
        });
        _ = try std.Io.Writer.alignBuffer(writer, tmp, 29, .left, ' ');

        // Percentiles
        try terminal.setColor(Color.cyan);
        tmp = try std.fmt.bufPrint(&buf, "{f}", .{
            Duration.fromNanoseconds(s.percentiles.p75),
        });
        _ = try std.Io.Writer.alignBuffer(writer, tmp, 11, .left, ' ');
        tmp = try std.fmt.bufPrint(&buf, "{f}", .{
            Duration.fromNanoseconds(s.percentiles.p99),
        });
        _ = try std.Io.Writer.alignBuffer(writer, tmp, 11, .left, ' ');
        tmp = try std.fmt.bufPrint(&buf, "{f}", .{
            Duration.fromNanoseconds(s.percentiles.p995),
        });
        _ = try std.Io.Writer.alignBuffer(writer, tmp, 11, .left, ' ');

        // End of line
        try terminal.setColor(Color.reset);
        try writer.writeAll("\n");

        if (self.readings.allocations) |allocs| {
            const m = try Statistics(usize).init(allocs.maxes);
            const trackmem_offset: usize = 52;

            // Benchmark name
            tmp = try std.fmt.bufPrint(&buf, "{s} [MEMORY]", .{truncated_name});
            _ = try std.Io.Writer.alignBuffer(writer, tmp, _name_len, .left, ' ');
            try writer.splatByteAll(' ', if (truncated_name.len > trackmem_offset - 1) 1 else trackmem_offset - truncated_name.len);

            // Mean + standard deviation
            try terminal.setColor(Color.green);
            try writer.print("{s:<23}", .{
                try std.fmt.bufPrint(&buf, "{Bi:.3} ± {Bi:.3}", .{
                    m.mean,
                    m.stddev,
                }),
            });
            // Minimum and maximum
            try terminal.setColor(Color.blue);
            try writer.print("{s:<29}", .{
                try std.fmt.bufPrint(&buf, "({Bi:.3} ... {Bi:.3})", .{
                    m.min,
                    m.max,
                }),
            });
            // Percentiles
            try terminal.setColor(Color.cyan);
            try writer.print("{Bi:<10.3} {Bi:<10.3} {Bi:<10.3}", .{
                m.percentiles.p75,
                m.percentiles.p99,
                m.percentiles.p995,
            });
            // End of line
            try terminal.setColor(Color.reset);
            try writer.writeAll("\n");
        }
    }

    /// Formats and prints the benchmark result in JSON format.
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
