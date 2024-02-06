const std = @import("std");

pub fn getCpuName(allocator: std.mem.Allocator) ![]const u8 {
    const stdout = try exec(allocator, &.{ "wmic", "cpu", "get", "name" });
    return stdout[41 .. stdout.len - 7];
}

fn exec(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const stdout = (try std.process.Child.exec(.{ .allocator = allocator, .argv = args })).stdout;
    return stdout[0 .. stdout.len - 1];
}
