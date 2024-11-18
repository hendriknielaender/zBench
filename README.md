# ⚡ zBench - A Zig Benchmarking Library

[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/hendriknielaender/zbench/blob/HEAD/LICENSE)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/hendriknielaender/zbench)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/hendriknielaender/zbench/blob/HEAD/CONTRIBUTING.md)
<img src="logo.png" alt="zBench logo" align="right" width="20%"/>

zBench is a benchmarking library for the Zig programming language. It is designed to provide easy-to-use functionality to measure and compare the performance of your code.

## Content

* [Installation](docs/install.md)
* [Usage](#usage)
* [Configuration](#configuration)
  * [Compatibility Notes](#compatibility-notes)
  * [Reporting Benchmarks](#reporting-benchmarks)
  * [Running zBench Examples](#running-zbench-examples)
  * [Troubleshooting](#troubleshooting)
* [Contributing](#contributing)
* [License](#license)

## Installation

For installation instructions, please refer to the [documentation](docs/install.md).

## Usage

Create a new benchmark function in your Zig code. This function takes a single argument of type `std.mem.Allocator` and runs the code you wish to benchmark.

```zig
fn benchmarkMyFunction(allocator: std.mem.Allocator) void {
    // Code to benchmark here
}
```

You can then run your benchmarks in a test:

```zig
test "bench test" {
    var bench = zbench.Benchmark.init(std.testing.allocator, .{});
    defer bench.deinit();
    try bench.add("My Benchmark", myBenchmark, .{});
    try bench.run(std.io.getStdOut().writer());
}
```

## Configuration

To customize your benchmark runs, zBench provides a `Config` struct that allows you to specify several options:

```zig
pub const Config = struct {
    iterations: u16 = 0,
    max_iterations: u16 = 16384,
    time_budget_ns: u64 = 2e9, // 2 seconds
    hooks: Hooks = .{},
    track_allocations: bool = false, 
};
```

* `iterations`: The number of iterations the benchmark has been run. This field is usually managed by zBench itself.
* `max_iterations`: Set the maximum number of iterations for a benchmark. Useful for controlling long-running benchmarks.
* `time_budget_ns`: Define a time budget for the benchmark in nanoseconds. Helps in limiting the total execution time of the benchmark.
* `hooks`: Set `before_all`, `after_all`, `before_each`, and `after_each` hooks to function pointers.
* `track_allocations`: Boolean to enable or disable tracking memory allocations during the benchmark.

### Compatibility Notes

#### Zig version

Zig is in active development and the APIs can change frequently, making it challenging to support every dev build. This project currently aims to be compatible with stable, non-development builds to provide a consistent experience for the users. As of now, zBench is tested and supported on Zig version **_0.13.0_**.

#### Performance Note

It's important to acknowledge that a no-op time of ca. 15 ns (or more) is expected and is not an issue with zBench itself (see also [#77](https://github.com/hendriknielaender/zBench/issues/77)). This does not reflect an inefficiency in the benchmarking process.

### Reporting Benchmarks

zBench provides a comprehensive report for each benchmark run. It includes the total operations performed, the average, min, and max durations of operations, and the percentile distribution (p75, p99, p995) of operation durations.

```shell
benchmark              runs     time (avg ± σ)         (min ... max)                p75        p99        p995
---------------------------------------------------------------------------------------------------------------
benchmarkMyFunction    1000     1200ms ± 10ms          (100ms ... 2000ms)           1100ms     1900ms     1950ms
```

This example report indicates that the benchmark "benchmarkMyFunction" ran with an average of 1200 ms per execution and a standard deviation of 10 ms.
The minimum and maximum execution times were 100 ms and 2000 ms, respectively. The 75th, 99th and 99.5th percentiles of execution times were 1100 ms, 1900 ms, and 1950 ms, respectively.

### Running zBench Examples

You can build all examples with the following command:

```shell
zig build examples
```

Executables can then be found in `./zig-out/bin` by default.

### Troubleshooting

* If Zig doesn't detect changes in a dependency, clear the project's `zig-cache` folder and `~/.cache/zig`.
* [Non-ASCII characters not printed correctly on Windows](docs/advanced.md)

## Contributing

The main purpose of this repository is to continue to evolve zBench, making it faster and more efficient. We are grateful to the community for contributing bugfixes and improvements. Read below to learn how you help improve zBench.

### Contributing Guide

Read our [contributing guide](CONTRIBUTING.md) to learn about our development process, how to propose bugfixes and improvements, and how to build and test your changes to zBench.

### License

zBench is [MIT licensed](./LICENSE).
