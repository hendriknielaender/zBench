const std = @import("std");

pub fn Statistics(comptime T: type) type {
    return struct {
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

        pub fn init(readings: []const T) Self {
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
            data: struct { []const u8, Self },
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
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

pub fn fmtJSON(
    comptime T: type,
    unit: []const u8,
    stats: Statistics(T),
) std.fmt.Formatter(Statistics(T).formatJSON) {
    return .{ .data = .{ unit, stats } };
}

// test "Statistics" {
//     {
//         var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
//         var allocs = std.ArrayList(usize).init(std.testing.allocator);
//         const r = try Result.init(
//             std.testing.allocator,
//             "r",
//             try timings_ns.toOwnedSlice(),
//             try allocs.toOwnedSlice(),
//         );
//         defer r.deinit();
//         const s = statistics.Statistics(u64).init(r.timings_ns);
//         try expectEq(@as(u64, 0), r.timings_ns_stats.mean);
//         try expectEq(@as(u64, 0), r.timings_ns_stats.stddev);
//     }

//     {
//         var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
//         var allocs = std.ArrayList(usize).init(std.testing.allocator);
//         try timings_ns.append(1);
//         try allocs.append(1);
//         const r = try Result.init(
//             std.testing.allocator,
//             "r",
//             try timings_ns.toOwnedSlice(),
//             try allocs.toOwnedSlice(),
//         );
//         defer r.deinit();
//         try expectEq(@as(u64, 1), r.timings_ns_stats.mean);
//         try expectEq(@as(u64, 0), r.timings_ns_stats.stddev);
//     }

//     {
//         var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
//         var allocs = std.ArrayList(usize).init(std.testing.allocator);
//         try timings_ns.append(1);
//         try allocs.append(1);
//         for (1..16) |i| try timings_ns.append(i);
//         for (1..16) |i| try allocs.append(i);
//         const r = try Result.init(
//             std.testing.allocator,
//             "r",
//             try timings_ns.toOwnedSlice(),
//             try allocs.toOwnedSlice(),
//         );
//         defer r.deinit();
//         try expectEq(@as(u64, 7), r.timings_ns_stats.mean);
//         try expectEq(@as(u64, 4), r.timings_ns_stats.stddev);
//     }

//     {
//         var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
//         var allocs = std.ArrayList(usize).init(std.testing.allocator);
//         try timings_ns.append(1);
//         try allocs.append(1);
//         for (1..101) |i| try timings_ns.append(i);
//         for (1..101) |i| try allocs.append(i);
//         const r = try Result.init(
//             std.testing.allocator,
//             "r",
//             try timings_ns.toOwnedSlice(),
//             try allocs.toOwnedSlice(),
//         );
//         defer r.deinit();
//         try expectEq(@as(u64, 50), r.timings_ns_stats.mean);
//         try expectEq(@as(u64, 29), r.timings_ns_stats.stddev);
//     }

//     {
//         var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
//         var allocs = std.ArrayList(usize).init(std.testing.allocator);
//         for (0..10) |_| try timings_ns.append(1);
//         for (0..10) |_| try allocs.append(1);
//         const r = try Result.init(
//             std.testing.allocator,
//             "r",
//             try timings_ns.toOwnedSlice(),
//             try allocs.toOwnedSlice(),
//         );
//         defer r.deinit();
//         try expectEq(@as(u64, 1), r.timings_ns_stats.mean);
//         try expectEq(@as(u64, 0), r.timings_ns_stats.stddev);
//     }

//     {
//         var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
//         var allocs = std.ArrayList(usize).init(std.testing.allocator);
//         for (0..100) |i| try timings_ns.append(i);
//         for (0..100) |i| try allocs.append(i);
//         const r = try Result.init(
//             std.testing.allocator,
//             "r",
//             try timings_ns.toOwnedSlice(),
//             try allocs.toOwnedSlice(),
//         );
//         defer r.deinit();
//         try expectEq(@as(u64, 75), r.timings_ns_stats.percentiles.p75);
//         try expectEq(@as(u64, 99), r.timings_ns_stats.percentiles.p99);
//         try expectEq(@as(u64, 99), r.timings_ns_stats.percentiles.p995);
//     }

//     {
//         var timings_ns = std.ArrayList(u64).init(std.testing.allocator);
//         var allocs = std.ArrayList(usize).init(std.testing.allocator);
//         for (0..100) |i| try timings_ns.append(i);
//         for (0..100) |i| try allocs.append(i);
//         std.mem.reverse(u64, timings_ns.items);
//         std.mem.reverse(u64, allocs.items);
//         const r = try Result.init(
//             std.testing.allocator,
//             "r",
//             try timings_ns.toOwnedSlice(),
//             try allocs.toOwnedSlice(),
//         );
//         defer r.deinit();
//         try expectEq(@as(u64, 75), r.timings_ns_stats.percentiles.p75);
//         try expectEq(@as(u64, 99), r.timings_ns_stats.percentiles.p99);
//         try expectEq(@as(u64, 99), r.timings_ns_stats.percentiles.p995);
//     }
// }
