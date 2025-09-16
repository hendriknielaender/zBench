const std = @import("std");
const zbench = @import("zbench");

fn myBenchmark1(_: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..100_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
    }
}

fn myBenchmark2(_: std.mem.Allocator) void {
    var result: usize = 0;
    for (0..200_000) |i| {
        std.mem.doNotOptimizeAway(i);
        result += i * i;
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var stdout = std.fs.File.stdout().writerStreaming(&.{});
    const writer = &stdout.interface;

    var bench = zbench.Benchmark.init(allocator, .{});
    defer bench.deinit();

    try bench.add("My Benchmark 1", myBenchmark1, .{});
    try bench.add("My Benchmark 2", myBenchmark2, .{});

    try writer.writeAll("\n");
    try zbench.prettyPrintHeader(writer);

    // Detect TTY configuration for color output
    const tty_config = std.Io.tty.Config.detect(std.fs.File.stdout());

    // Initialize the std.Progress api
    const progress = std.Progress.start(.{});
    defer progress.end();

    // Parent node with total count
    const suite_node = progress.start("Benchmarks", 2);
    defer suite_node.end();

    var iter = try bench.iterator();
    var current_benchmark: []const u8 = "";
    var benchmark_node: ?std.Progress.Node = null;
    var completed_benchmarks: usize = 0;

    while (try iter.next()) |step| switch (step) {
        .progress => |p| {
            if (p.total_runs > 0) {
                // Check if we've moved to a new benchmark
                if (!std.mem.eql(u8, current_benchmark, p.current_name)) {
                    if (benchmark_node) |*node| {
                        node.end();
                    }

                    current_benchmark = p.current_name;
                    benchmark_node = suite_node.start(p.current_name, p.total_runs);
                }

                // Update the child progress node to show completed runs
                if (benchmark_node) |*node| {
                    node.setCompletedItems(p.completed_runs);
                }
            }
        },
        .result => |x| {
            defer x.deinit();

            if (benchmark_node) |*node| {
                node.end();
                benchmark_node = null;
            }

            // Update the parent progress node to show completed benchmarks
            completed_benchmarks += 1;
            suite_node.setCompletedItems(completed_benchmarks);

            // Print the result
            try x.prettyPrint(allocator, writer, tty_config);
        },
    };

    // Clean up any remaining benchmark node
    if (benchmark_node) |*node| {
        node.end();
    }
}
