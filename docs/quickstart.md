# Quick Start

This guide helps you quickly start using zBench in your Zig projects.

## Installation

You can integrate zBench into your project either using `build.zig.zon` or as a git submodule.

### Using `build.zig.zon`

Declare zbench as a dependency and add it to your `build.zig.zon`. Replace `<COMMIT>` with the specific commit hash or tag.

## Writing Benchmarks

Import zbench in your Zig code and create a benchmark function:

```zig
const std = @import("std");
const zbench = @import("zbench");

fn myBenchRunner(_: std.mem.Allocator) void {
    // Code to benchmark here
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const second: u64 = 1_000_000_000;
    const bench_iterations: u64 = 128;

    var bench = try zbench.Benchmark.init(second, bench_iterations, gpa.allocator());
    defer bench.deinit();

    const bench_result = try bench.run(myBenchRunner, "Hello bench");
    try bench_result.prettyPrint(true);
}
```


