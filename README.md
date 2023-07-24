# zBench - A Simple Zig Benchmarking Library
zBench is a simple benchmarking library for the Zig programming language. It is designed to provide easy-to-use functionality to measure and compare the performance of your code.

## Import the library
In your Zig project, import the zBench package to your `build.zig` file:

On your project root directory make a directory name libs.
- Run `git submodule add https://github.com/hendriknielaender/zBench libs/zbench`
- Then add the module into your `build.zig`
```zig
exe.addAnonymousModule("zbench", .{
    .source_file = .{ .path = "libs/zbench/zbench.zig" },
}); 
```
Now you can import like this:

```zig
const zbench = @import("zbench");
```

## Usage
Create a new benchmark function in your Zig code. This function should take a single argument of type *zbench.Benchmark. The function would run the code you wish to benchmark.

```zig
fn benchmarkMyFunction(b: *zbench.Benchmark) void {
    // Code to benchmark here
}
```
You can then run your benchmarks in the main function:
```zig
pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var b = try zBench.Benchmark.init("benchmarkMyFunction", &allocator);
    try zBench.run(benchmarkMyFunction, &b);
}
```

### Benchmark Functions
Benchmark functions have the following signature:

```zig
fn(b: *zbench.Benchmark) void
```
The function body contains the code you wish to benchmark.

You can run multiple benchmark functions in a single program by using zBench.run for each benchmark function.

### Reporting Benchmarks

zBench provides a comprehensive report for each benchmark run. It includes the total operations performed, the average, min, and max durations of operations, and the percentile distribution (p75, p99, p995) of operation durations. 

```yaml
benchmark           time (avg)    (min ... max)    p75        p99        p995
--------------------------------------------------------------------------------------
benchmarkMyFunction 1200 ms       (100 ms ... 2000 ms) 1100 ms   1900 ms   1950 ms
```

This example report indicates that the benchmark "benchmarkMyFunction" was run with an average time of 1200 ms per operation. The minimum and maximum operation times were 100 ms and 2000 ms, respectively. The 75th, 99th, and 99.5th percentiles of operation durations were 1100 ms, 1900 ms, and 1950 ms, respectively.
