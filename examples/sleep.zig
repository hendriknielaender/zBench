const std = @import("std");
const zbench = @import("zbench");
const log = std.log.scoped(.zbench_example_sleep);

const SleepBenchmark = struct {
    io: std.Io,

    pub fn run(self: *SleepBenchmark, _: std.mem.Allocator) void {
        self.io.sleep(.fromMilliseconds(100), .awake) catch |err| {
            log.err("sleep failed: {}", .{err});
        };
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const stdout: std.Io.File = .stdout();
    const sleep_benchmark = SleepBenchmark{ .io = io };

    var bench = zbench.Benchmark.init(init.gpa, .{});
    defer bench.deinit();

    try bench.addParam("Sleep Benchmark", &sleep_benchmark, .{});
    try bench.run(io, stdout);
}
