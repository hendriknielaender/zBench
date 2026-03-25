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

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const stdout: std.Io.File = .stdout();

    var bench = zbench.Benchmark.init(init.gpa, .{});
    defer bench.deinit();

    try bench.add("My Benchmark 1", myBenchmark1, .{});
    try bench.add("My Benchmark 2", myBenchmark2, .{});

    try zbench.prettyPrintHeader(
        io,
        stdout,
        bench.max_name_len,
    );

    // Initialize the std.Progress api
    const progress = std.Progress.start(io, .{});
    defer progress.end();

    // Parent node with total count
    const suite_node = progress.start("Benchmarks", 2);
    defer suite_node.end();

    var iter = try bench.iterator();
    var current_benchmark: []const u8 = "";
    var benchmark_node: ?std.Progress.Node = null;
    var completed_benchmarks: usize = 0;

    while (try iter.next(io)) |step| switch (step) {
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
        .result => |r| {
            defer r.deinit();

            if (benchmark_node) |*node| {
                node.end();
                benchmark_node = null;
            }

            // Update the parent progress node to show completed benchmarks
            completed_benchmarks += 1;
            suite_node.setCompletedItems(completed_benchmarks);

            try r.prettyPrint(io, stdout, bench.max_name_len);
        },
    };

    // Clean up any remaining benchmark node
    if (benchmark_node) |*node| {
        node.end();
    }
}
