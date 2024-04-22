const std = @import("std");
const log = std.log.scoped(.zbench_platform_osx);

pub fn getCpuName(allocator: std.mem.Allocator) ![]const u8 {
    return try exec(allocator, &.{ "sysctl", "-n", "machdep.cpu.brand_string" });
}

pub fn getCpuCores(allocator: std.mem.Allocator) !u32 {
    const str = try exec(allocator, &.{ "sysctl", "-n", "hw.physicalcpu" });
    return std.fmt.parseInt(u32, str, 10) catch |err| {
        log.err("Error parsing CPU cores count: {}\n", .{err});
        return err;
    };
}

pub fn getTotalMemory(allocator: std.mem.Allocator) !u64 {
    const str = try exec(allocator, &.{ "sysctl", "-n", "hw.memsize" });
    return std.fmt.parseInt(u64, str, 10) catch |err| {
        log.err("Error parsing total memory size: {}\n", .{err});
        return err;
    };
}

fn exec(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const stdout = (try std.process.Child.run(.{ .allocator = allocator, .argv = args })).stdout;

    if (stdout.len == 0) return error.EmptyOutput;

    return stdout[0 .. stdout.len - 1];
}
