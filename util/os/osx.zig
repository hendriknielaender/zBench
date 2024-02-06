const std = @import("std");

pub fn getCpuName(allocator: std.mem.Allocator) ![]const u8 {
    return try exec(allocator, &.{ "sysctl", "-n", "machdep.cpu.brand_string" });
}

fn exec(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const stdout = (try std.process.Child.exec(.{ .allocator = allocator, .argv = args })).stdout;
    return stdout[0 .. stdout.len - 1];
}
