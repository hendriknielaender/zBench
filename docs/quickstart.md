# Quick Start

This guide helps you quickly start using zBench in your Zig projects.

## Installation

You can integrate zBench into your project either using `build.zig.zon` or as a git submodule.

### Using `build.zig.zon`

Declare zbench as a dependency and add it to your `build.zig.zon`. Replace `<COMMIT>` with the specific commit hash or tag.

## Writing Benchmarks

Import zbench in your Zig code and create a benchmark function:

```zig
const zbench = @import("zbench");

fn benchmarkMyFunction(_: *zbench.Benchmark) void {
    // Benchmark code here
}
```

Run the benchmark in a test:

```zig
pub fn main() !void {
    const resultsAlloc = std.ArrayList(zbench.BenchmarkResult).init(test_allocator);
    var bench = try zbench.Benchmark.init("My Benchmark", std.heap.page_allocator);
    var benchmarkResults = zbench.BenchmarkResults{
        .results = resultsAlloc,
    };
    defer benchmarkResults.results.deinit();
    try zbench.run(myBenchmark, &bench, &benchmarkResults);
}
```
