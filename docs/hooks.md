# Hooks

This guide explains what lifecycle hooks are and how to use them.

## Concepts

Lifecycle hooks provide control over a benchmark environment. A hook is a function with the following signature: `fn () void`. Its execution is not included in the benchmark reports.

There are 4 kinds of hooks summarised in the following table:

| Hook          | When is it called ?                    | Goal/Actions       | Example(s)                                              |
|---------------|----------------------------------------|--------------------|---------------------------------------------------------|
| `before_all`  | Executed at the start of the benchmark | Global setup       | Allocate memory, initialize variables for the benchmark |
| `before_each` | Executed before each iteration         | Iteration setup    | Setup/Allocate benchmark data                           |
| `after_each`  | Executed after each iteration          | Iteration teardown | Reset/Free benchmark data                               |
| `after_all`   | Executed at the end of the benchmark   | Global teardown    | Free memory, deinit variables                           |

## Usage

zBench provides two ways to register hooks: globally or for a given benchmark. 

---

Global registration adds hooks to each added benchmark.

```zig
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{ .hooks = .{
        .before_all = beforeAllHook,
        .after_all = afterAllHook,
    } });
    defer bench.deinit();

    try bench.add("Benchmark 1 ", myBenchmark, .{});
    try bench.add("Benchmark 2 ", myBenchmark, .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
```

In this example, both Benchmark 1 and Benchmark 2 will execute `beforeAllHook` and `afterAllHook`. Note that `before_each` and `after_each` can be omitted because hooks are optional.

---

Hooks can also be included with the `add` and `addParam` methods. 

```zig
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(std.heap.page_allocator, .{});
    defer bench.deinit();

    try bench.add("Benchmark 1", myBenchmark, .{
        .hooks = .{
            .before_all = beforeAllHook,
            .after_all = afterAllHook,
        },
    });

    try bench.add("Benchmark 2", myBenchmark, .{});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}
```

In this example, only Benchmark 1 will execute `beforeAllHook` and `afterAllHook`.
