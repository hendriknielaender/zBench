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
To use zbench, create a new benchmark function. This function should take a single argument of type *zbench.B and return void.

```zig
fn benchmarkMyFunction(b: *zbench.B) void {
    for (b.iter()) |_| {
        // Code to benchmark here
    }
}
```
You can then run your benchmarks in the main function:
```zig
pub fn main() !void {
    _ = try zBench.run(benchmarkMyFunction);
}
```

Benchmark Functions
Benchmark functions have the following signature:

```zig
fn(b: *zBench.B) void
```
In the body of the function, you should loop over b.iter(), executing the code you wish to benchmark for each iteration. The b.iter() method automatically scales the number of iterations to provide a useful amount of data, no matter how fast or slow the benchmarked code is.

You can benchmark multiple functions in a single program. Use zBench.run for each benchmark function.

### Benchmark Options
If you want to control the number of iterations for the benchmark explicitly, you can use the N field of the zBench.B struct:

```zig
fn benchmarkMyFunction(b: *zBench.B) void {
    b.N = 1000; // Run the benchmark 1000 times
    for (b.iter()) |_| {
        // Code to benchmark here
    }
}
```
### Reporting Benchmarks
By default, zBench will output benchmark results to the console. The output includes the benchmark name, the number of iterations, and the time taken per iteration.

```yaml
benchmarkMyFunction  1000  1200 ns/op
```
