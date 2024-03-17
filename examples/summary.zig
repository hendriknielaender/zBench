const std = @import("std");
const zbench = @import("zbench");
const test_allocator = std.testing.allocator;

fn function1() []const u8 {
    var result: usize = 0;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const square = i * i;
        result += square;
    }

    return "Hello, world!";
}

fn function2() []const u8 {
    var result: usize = 0;
    var i: usize = 0;
    while (i < 20000) : (i += 1) {
        const square = i * i;
        result += square;
    }

    return "Hello, world!";
}

fn function3() []const u8 {
    var result: usize = 0;
    var i: usize = 0;
    while (i < 300000) : (i += 1) {
        const square = i * i;
        result += square;
    }

    return "Hello, world!";
}

fn fn1(_: std.mem.Allocator) void {
    _ = function1();
}

fn fn2(_: std.mem.Allocator) void {
    _ = function2();
}

fn fn3(_: std.mem.Allocator) void {
    _ = function3();
}

test "bench test basic" {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(test_allocator, .{});
    defer bench.deinit();

    try bench.add("fast function", fn1, .{
        .iterations = 10,
    });

    try bench.add("medium fast function", fn2, .{
        .iterations = 10,
    });

    try bench.add("slow function", fn3, .{
        .iterations = 10,
    });

    const results = try bench.run();
    defer results.deinit();

    try results.prettyPrint(stdout, true);
    try results.printSummary(stdout);
}
