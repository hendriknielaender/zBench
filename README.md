<h1 align="center">
   <img src="logo.png" width="20%" height="20%" alt="zBench logo" title="zBench logo">
  <br><br>
  ⚡ zBench - A Simple Zig Benchmarking Library
</h1>
<div align="center">
zBench is a simple benchmarking library for the Zig programming language. It is designed to provide easy-to-use functionality to measure and compare the performance of your code.
</div>
<br><br>

## Install Option 1 (build.zig.zon)
Create a build.zig.zon file in your project with the following contents:
   ```zig
   .{
       .name = "YOUR_PROJECT",
       .paths = .{""},
       .version = "0.0.0",
       .dependencies = .{
           .zbench = .{
               .url = "https://github.com/hendriknielaender/zbench/archive/COMMIT_HASH.tar.gz",
               .hash = "DUMMY_HASH"
           },
       },
   }
   ```
Update your `build.zig` to use the `zbench` dependency:
  ```zig
  const zbench_dep = b.dependency("zbench", .{.target = target,.optimize = optimize});
  const zbench_module = zbench_dep.module("zbench");
  ```
Upon running `zig build test`, if you encounter a hash mismatch error, update the hash value in your `build.zig.zon` with the correct hash provided in the error message.

## Install Option 2 (git submodule)
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
You can then run your benchmarks in a test:
```zig
test "bench test" {
    var allocator = std.heap.page_allocator;
    var b = try zBench.Benchmark.init("benchmarkMyFunction", &allocator);
    try zBench.run(benchmarkMyFunction, &b);
}
```

### Compatibility Notes
Zig is in active development and the APIs can change frequently, making it challenging to support every dev build. This project currently aims to be compatible with stable, non-development builds to provide a consistent experience for the users.

***Supported Version***: As of now, zBench is tested and supported on Zig version ***0.11.0***.

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

### Running zBench Examples

You can run all example tests with the following command:
```bash
zig build test_examples
```

### Troubleshooting
If Zig doesn't detect changes in a dependency, clear the project's `zig-cache` folder and `~/.cache/zig`.
