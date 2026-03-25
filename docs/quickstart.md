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

fn benchmarkMyFunction(_: std.mem.Allocator) void {
    // Benchmark code here
}
```

Run the benchmark from main:

```zig
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const stdout: std.Io.File = .stdout();

    var bench = zbench.Benchmark.init(init.gpa, .{});
    defer bench.deinit();

    try bench.add("My Benchmark", benchmarkMyFunction, .{});
    try bench.run(io, stdout);
}
```
