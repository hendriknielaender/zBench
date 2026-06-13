const std = @import("std");

/// Collect common statistical calculations together.
pub fn Statistics(comptime T: type) type {
    return struct {
        const Data = struct { []const u8, Self };

        total: T,
        mean: T,
        stddev: T,
        min: T,
        max: T,
        percentiles: Percentiles,

        const Self = @This();

        pub const Percentiles = struct {
            p75: T,
            p99: T,
            p995: T,
        };

        /// Create a statistical summary of a dataset.
        ///
        /// Sortes "readings" slice in ascending order to get min and max.
        /// Note: since this is a pointer type, this modification affects
        /// the slice at the call site.
        pub fn init(readings: []T) !Self {
            const len = readings.len;

            // Calculate total and mean
            var total: T = 0;
            for (readings) |n| total += n;
            const mean: T = if (0 < len) total / len else 0;

            // Calculate standard deviation
            const stddev: T = blk: {
                var nvar: T = 0;
                for (readings) |n| {
                    const sd = if (n < mean) mean - n else n - mean;
                    nvar += sd * sd;
                }
                break :blk if (1 < len) std.math.sqrt(nvar / (len - 1)) else 0;
            };

            std.sort.heap(T, readings, {}, std.sort.asc(T));

            return Self{
                .total = total,
                .mean = mean,
                .stddev = stddev,
                .min = if (len == 0) 0 else readings[0],
                .max = if (len == 0) 0 else readings[len - 1],
                .percentiles = Percentiles{
                    .p75 = if (len == 0) 0 else readings[len * 75 / 100],
                    .p99 = if (len == 0) 0 else readings[len * 99 / 100],
                    .p995 = if (len == 0) 0 else readings[len * 995 / 1000],
                },
            };
        }

        fn formatJSON(
            data: Data,
            writer: *std.Io.Writer,
        ) !void {
            try writer.print(
                \\{{ "units": "{s}",
                \\   "total": {d},
                \\   "mean": {d},
                \\   "stddev": {d},
                \\   "min": {d},
                \\   "max": {d},
                \\   "percentiles": {{"p75": {d}, "p99": {d}, "p995": {d} }} }}
            ,
                .{
                    data[0],
                    data[1].total,
                    data[1].mean,
                    data[1].stddev,
                    data[1].min,
                    data[1].max,
                    data[1].percentiles.p75,
                    data[1].percentiles.p99,
                    data[1].percentiles.p995,
                },
            );
        }
    };
}

pub fn throughputPerSecond(
    processed_per_run: usize,
    iterations: usize,
    total_ns: u64,
) f64 {
    if (total_ns == 0) return 0;

    const total_processed =
        @as(f64, @floatFromInt(processed_per_run)) *
        @as(f64, @floatFromInt(iterations));

    const seconds =
        @as(f64, @floatFromInt(total_ns)) /
        @as(f64, @floatFromInt(std.time.ns_per_s));

    return total_processed / seconds;
}

pub fn fmtJSON(
    comptime T: type,
    unit: []const u8,
    stats: Statistics(T),
) std.fmt.Alt(Statistics(T).Data, Statistics(T).formatJSON) {
    return .{ .data = .{ unit, stats } };
}

test Statistics {
    const expectEqDeep = std.testing.expectEqualDeep;
    {
        var timings_ns = std.array_list.Managed(u64).init(std.testing.allocator);
        defer timings_ns.deinit();
        try expectEqDeep(Statistics(u64){
            .total = 0,
            .mean = 0,
            .stddev = 0,
            .min = 0,
            .max = 0,
            .percentiles = .{
                .p75 = 0,
                .p99 = 0,
                .p995 = 0,
            },
        }, try Statistics(u64).init(timings_ns.items));
    }

    {
        var timings_ns = std.array_list.Managed(u64).init(std.testing.allocator);
        defer timings_ns.deinit();
        try timings_ns.append(1);
        try expectEqDeep(Statistics(u64){
            .total = 1,
            .mean = 1,
            .stddev = 0,
            .min = 1,
            .max = 1,
            .percentiles = .{
                .p75 = 1,
                .p99 = 1,
                .p995 = 1,
            },
        }, try Statistics(u64).init(timings_ns.items));
    }

    {
        var timings_ns = std.array_list.Managed(u64).init(std.testing.allocator);
        defer timings_ns.deinit();
        try timings_ns.append(1);
        for (1..16) |i| try timings_ns.append(i);
        try expectEqDeep(Statistics(u64){
            .total = 121,
            .mean = 7,
            .stddev = 4,
            .min = 1,
            .max = 15,
            .percentiles = .{
                .p75 = 12,
                .p99 = 15,
                .p995 = 15,
            },
        }, try Statistics(u64).init(timings_ns.items));
    }

    {
        var timings_ns = std.array_list.Managed(u64).init(std.testing.allocator);
        defer timings_ns.deinit();
        try timings_ns.append(1);
        for (1..101) |i| try timings_ns.append(i);
        try expectEqDeep(Statistics(u64){
            .total = 5051,
            .mean = 50,
            .stddev = 29,
            .min = 1,
            .max = 100,
            .percentiles = .{
                .p75 = 75,
                .p99 = 99,
                .p995 = 100,
            },
        }, try Statistics(u64).init(timings_ns.items));
    }

    {
        var timings_ns = std.array_list.Managed(u64).init(std.testing.allocator);
        defer timings_ns.deinit();
        try timings_ns.append(1);
        for (1..101) |i| try timings_ns.append(i);
        std.mem.reverse(u64, timings_ns.items);
        try expectEqDeep(Statistics(u64){
            .total = 5051,
            .mean = 50,
            .stddev = 29,
            .min = 1,
            .max = 100,
            .percentiles = .{
                .p75 = 75,
                .p99 = 99,
                .p995 = 100,
            },
        }, try Statistics(u64).init(timings_ns.items));
    }

    {
        var timings_ns = std.array_list.Managed(u64).init(std.testing.allocator);
        defer timings_ns.deinit();
        try timings_ns.append(1);
        for (1..101) |i| try timings_ns.append(i);
        var prng = std.Random.DefaultPrng.init(0);
        const random = prng.random();
        random.shuffle(u64, timings_ns.items);
        try expectEqDeep(Statistics(u64){
            .total = 5051,
            .mean = 50,
            .stddev = 29,
            .min = 1,
            .max = 100,
            .percentiles = .{
                .p75 = 75,
                .p99 = 99,
                .p995 = 100,
            },
        }, try Statistics(u64).init(timings_ns.items));
    }
}
