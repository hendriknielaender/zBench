const std = @import("std");

pub fn getCpuName(allocator: std.mem.Allocator) ![]const u8 {
    return try exec(allocator, &.{ "sysctl", "-n", "machdep.cpu.brand_string" });
}

pub fn getCpuCores(allocator: std.mem.Allocator) !u32 {
    const coresString = try exec(allocator, &.{ "sysctl", "-n", "hw.physicalcpu" });
    defer allocator.free(coresString);

    return std.fmt.parseInt(u32, coresString, 10) catch |err| {
        std.debug.print("Error parsing CPU cores count: {}\n", .{err});
        return err;
    };
}

pub fn getTotalMemory(allocator: std.mem.Allocator) !u64 {
    const memSizeString = try exec(allocator, &.{ "sysctl", "-n", "hw.memsize" });
    defer allocator.free(memSizeString);

    // Parse the string to a 64-bit unsigned integer
    return std.fmt.parseInt(u64, memSizeString, 10) catch |err| {
        std.debug.print("Error parsing total memory size: {}\n", .{err});
        return err;
    };
}

fn exec(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const stdout = (try std.process.Child.exec(.{ .allocator = allocator, .argv = args })).stdout;
    return stdout[0 .. stdout.len - 1];
}
