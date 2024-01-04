# ⚡ zBench - A Simple Zig Benchmarking Library
[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/hendriknielaender/zbench/blob/HEAD/LICENSE)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/hendriknielaender/zbench)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/hendriknielaender/zbench/blob/HEAD/CONTRIBUTING.md)
<img src="logo.png" alt="zBench logo" align="right" width="20%"/>

zBench is a simple benchmarking library for the Zig programming language. It is designed to provide easy-to-use functionality to measure and compare the performance of your code.

(This is a fork of the original zBench repository. Check the Usage section below to see what's new.
**NOTE:** this fork requires a version 0.12.0 compiler).

## Install Option 1 (build.zig.zon)

1. Declare zbench as a dependency in `build.zig.zon`:

    ```diff
    .{
        .name = "my-project",
        .version = "1.0.0",
        .paths = .{""},
        .dependencies = .{
    +       .zbench = .{
    +           .url = "https://github.com/hendriknielaender/zbench/archive/<COMMIT>.tar.gz",
    +       },
        },
    }
    ```

2. Add the module in `build.zig`:

    ```diff
    const std = @import("std");

    pub fn build(b: *std.Build) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});

    +   const opts = .{ .target = target, .optimize = optimize };
    +   const zbench_module = b.dependency("zbench", opts).module("zbench");

        const exe = b.addExecutable(.{
            .name = "test",
            .root_source_file = .{ .path = "src/main.zig" },
            .target = target,
            .optimize = optimize,
        });
    +   exe.addModule("zbench", zbench_module);
        exe.install();

        ...
    }
    ```

3. Get the package hash:

    ```
    $ zig build
    my-project/build.zig.zon:6:20: error: url field is missing corresponding hash field
            .url = "https://github.com/hendriknielaender/zbench/archive/<COMMIT>.tar.gz",
                   ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    note: expected .hash = "<HASH>",
    ```

4. Update `build.zig.zon` package hash value:

    ```diff
    .{
        .name = "my-project",
        .version = "1.0.0",
        .paths = .{""},
        .dependencies = .{
            .zbench = .{
                .url = "https://github.com/hendriknielaender/zbench/archive/<COMMIT>.tar.gz",
    +           .hash = "<HASH>",
            },
        },
    }
    ```

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

### Compatibility Notes

***Supported Version***: As of now, this fork of zBench is tested and supported on Zig version ***0.12.0-dev.1849+bb0f7d55e***.

## Usage
The main type in this library is the `Benchmark` which contains the state for a single benchmark at any given time. A single instance can (and should) run several
benchmarks, just not concurrently. You can make use of the timing functionality in `Benchmark` to get timings directly, or you can pass a bench-runner to the `run`
function. The latter is the simplest, and fits most usecases. Here are some examples:

### Standalone function
The simplest case is when you wish to benchmark a standalone function
```zig
fn myBenchRunner() void {
    // Code to benchmark here
}
```
You can then run your benchmarks in either a test, or main as an executable. The latter is preferable as tests can generate noise and obscure the benchmark output.
Next we instantiate a `Benchmark` instance.
```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
 
    const second: u64 = 1_000_000_000;
    const bench_iterations: u64 = 128;

    var bench = try zbench.Benchmark.init(second, bench_iterations, gpa.allocator());
    defer bench.deinit();
}
```
The first argument to `init` is an estimate in nanoseconds for the maximum amount of time we are willing to wait for any given benchmark to finish,
the second argument is the maximum number of repetitions or runs for each benchmark. Now to perform the benchmark we pass `myBenchRunner` to `bench.run`,
and the name of our benchmark. The complete example looks like this:
```zig
const std = @import("std");
const zbench = @import("zbench");

fn myBenchRunner() void {
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
`bench.run` returns a `BenchmarkResult` which can be pretty-printed (more parsing functionality may be added in the future):
```yaml
benchmark                 runs     time (avg ± σ)         (min ............. max)      p75        p99        p995
---------------------------------------------------------------------------------------------------------------------
Hello bench               128      8.806µs ± 67.0ns       (8.351µs ... 9.185µs)        8.813µs    9.31µs     9.185µs
```
If `myBenchRunner` needs to allocate we could have declared `std.mem.Allocator` as a parameter:
```zig
fn myBenchRunner(alloc: std.mem.Allocator) void {
    // Code to benchmark here
}
```
### Aggregate runner
In most cases we want to first set up some state relevant to the benchmark, but we aren't interested in benchmarking the state setup code.
You can use an aggregate runner (ie. struct) to split such initialisation from run code:
```zig
const std = @import("std");
const zbench = @import("zbench");

const StructRunner = struct {
    const Self = @This();

    nums: [10]u64,

    pub fn init(_: std.mem.Allocator) !Self {
        return Self { .nums = .{1, 2, 3, 4, 5, 6, 7, 8, 9, 10} };
    }

    pub fn run(self: *Self) void {
        var i: usize = 1;
        while (i < self.nums.len) : (i += 1) {
            self.nums[i] += self.nums[i-1];
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const second: u64 = 1_000_000_000;
    const bench_iterations: u64 = 128;

    var bench = try zbench.Benchmark.init(second, bench_iterations, gpa.allocator());
    defer bench.deinit();

    const bench_result = try bench.run(StructRunner, "Cumulative sum?");
    try bench_result.prettyPrint(true);
}
```
Now instead of a standalone function our runner is a struct with the methods `init` and `run`. It's free to have other methods as well,
but it must include those two. The run function must take either `Self` or `*Self`, and the init function must take `std.mem.Allocator`.

### Aggregate runner with cleanup
If your runner has to do some form of cleanup such as de-allocating memory, you can additionally declare a `deinit` method. Lets write a runner for benchmarking the
append-function of the standard library ArrayList. In this case we aren't interested in re-allocating, so we will pre-allocate the space we need:
```zig
const std = @import("std");
const zbench = @import("zbench");

const StructRunner = struct {
    const Self = @This();

    list: std.ArrayList(usize),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !Self {
        return Self {
            .list = try std.ArrayList(usize).initCapacity(alloc, 512),
            .alloc = alloc,
        };
    }

    pub fn run(self: *Self) void {
        for (0..512) |i| self.list.append(i) catch @panic("Append failed!");
    }

    pub fn deinit(self: Self) void { self.list.deinit(); }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const second: u64 = 1_000_000_000;
    const bench_iterations: u64 = 128;

    var bench = try zbench.Benchmark.init(second, bench_iterations, gpa.allocator());
    defer bench.deinit();

    const bench_result = try bench.run(StructRunner, "ArrayList append");
    try bench_result.prettyPrint(true);
}
```
Note that we can't return errors from `run`, so any errors that occur must be handled immediately and can't be propagated.
### Aggregate runner with reset
In order to prevent dependance, `Benchmark` creates a new instance of `StructRunner` between every benchmarking run (this doesn't ensure independance however, you can
still write/read from global variables in your `run` for example). This involves `init`ing and `deinit`ing every instance between every run, which involves memory allocations.
In this case (and a lot of cases) that causes easely avoidable slowdowns of our benchmarks. To avoid this we can additionally declare a `reset` method for our runner
that resets the state, here's how that would look like for the above runner:
```zig
const StructRunner = struct {
    const Self = @This();

    list: std.ArrayList(usize),
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) !Self {
        return Self {
            .list = try std.ArrayList(usize).initCapacity(alloc, 512),
            .alloc = alloc,
        };
    }

    pub fn run(self: *Self) void {
        for (0..512) |i| self.list.append(i) catch @panic("Append failed!");
    }

+   pub fn reset(self: *Self) void {
+       self.list.clearRetainingCapacity();
+   }

    pub fn deinit(self: Self) void { self.list.deinit(); }
};
```
Now `reset` is instead called for every benchmark-run, and `init`/`deinit` are only called once at the start and end of the benchmark respectively.

### Running and printing multiple benchmarks
You can print multiple results by use the convenience-function `zbench.prettyPrintResults` or just printing them in a for-loop without the header. Here's the `sleep.zig`
example:
```zig
const std = @import("std");
const zbench = @import("zbench");

fn sleepyFirstRunner(_: std.mem.Allocator) void {
    std.time.sleep(100_000);
}

fn sleepySecondRunner(_: std.mem.Allocator) void {
    std.time.sleep(1_000_000);
}

fn sleepyThirdRunner(_: std.mem.Allocator) void {
    std.time.sleep(10_000_000);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const second: u64 = 1_000_000_000;
    const bench_iterations: u64 = 128;

    var bench = try zbench.Benchmark.init(second, bench_iterations, gpa.allocator());
    defer bench.deinit();

    const result1 = try bench.run(sleepyFirstRunner, "Sleepy-first bench");
    const result2 = try bench.run(sleepySecondRunner, "Sleepy-second bench");
    const result3 = try bench.run(sleepyThirdRunner, "Sleepy-third bench");

    try zbench.prettyPrintResults(&.{result1, result2, result3}, true);
}
```
```yaml
benchmark                 runs     time (avg ± σ)         (min ............. max)      p75        p99        p995      
---------------------------------------------------------------------------------------------------------------------
Sleepy-first bench        128      161.812µs ± 46.419µs   (157.87µs ... 682.646µs)     157.846µs  170.807µs  682.646µs 
Sleepy-second bench       128      1.237ms ± 89.535µs     (1.58ms ... 1.925ms)         1.243ms    1.752ms    1.925ms   
Sleepy-third bench        98       10.259ms ± 161.244µs   (10.78ms ... 11.558ms)       10.248ms   11.558ms   11.558ms
```
Check out the [linked_list](./examples/linked_list.zig) example for how to use zig's comptime to neatly run multiple benchmarks.

### Using the timing functionality in `Benchmark` directly
TODO

### Benchmark Runners
Benchmark runners must be one of either
- Standalone function with *either* of the following signature/function type
   - `fn (std.mem.Allocator) void`
   - `fn () void`

- Aggregate (Struct/Union/Enum) with following associated methods
  - `pub fn init(std.mem.Allocator) !Self`  : (Required)
  - `pub fn run(Self) void`                 : (Required)
  - `pub fn deinit(Self) void`              : (Optional)
  - `pub fn reset(Self) void`               : (Optional)

The function signatures must match, but `*Self` instead of `Self` also works for the above methods

### Reporting Benchmarks

zBench provides a comprehensive report for each benchmark run. It includes the total operations performed, the average, min, and max durations of operations, and the percentile distribution (p75, p99, p995) of operation durations.

```yaml
benchmark                 runs     time (avg ± σ)         (min ............. max)      p75        p99        p995
---------------------------------------------------------------------------------------------------------------------
Hello bench               128      8.806µs ± 67.0ns       (8.351µs ... 9.185µs)        8.813µs    9.31µs     9.185µs
```

This example report indicates that the benchmark "benchmarkMyFunction" was run with an average time of 8.806 µs with standard deviation 67.0 ns per operation.
The minimum and maximum operation times were 8.351µs and 9.185µs, respectively. The 75th, 99th, and 99.5th percentiles of operation durations were
8.813µs, 9.31µs, 9.185µs, respectively.

### Running zBench Examples and Tests

You can compile all examples with the following command:
```bash
zig build examples
```
The binaries are placed by default in `./zBench/zig-out/bin/`

You can run all tests with

```bash
zig build test
```

### Troubleshooting

If Zig doesn't detect changes in a dependency, clear the project's `zig-cache` folder and `~/.cache/zig`.

## Contributing

The main purpose of this repository is to continue to evolve zBench, making it faster and more efficient. We are grateful to the community for contributing bugfixes and improvements. Read below to learn how you can take part in improving zBench.

### Contributing Guide

Read our [contributing guide](CONTRIBUTING.md) to learn about our development process, how to propose bugfixes and improvements, and how to build and test your changes to zBench.

### License

zBench is [MIT licensed](./LICENSE).
