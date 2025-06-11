const std = @import("std");
const log = std.log.scoped(.zbench_platform_windows);

pub fn getCpuName(allocator: std.mem.Allocator) ![]const u8 {
    const stdout = try exec(allocator, &.{ "wmic", "cpu", "get", "name" });

    // Ensure stdout is long enough before slicing
    if (stdout.len < 52) return error.InsufficientLength;

    return stdout[45 .. stdout.len - 7];
}

pub fn getCpuCores(allocator: std.mem.Allocator) !u32 {
    // Use provided allocator for WMIC command execution
    const stdout = try exec(allocator, &.{ "wmic", "cpu", "get", "NumberOfCores", "/format:value" });

    // Find NumberOfCores=X pattern
    if (std.mem.indexOf(u8, stdout, "NumberOfCores=")) |pos| {
        const start = pos + "NumberOfCores=".len;
        var end = start;
        while (end < stdout.len and std.ascii.isDigit(stdout[end])) : (end += 1) {}
        
        if (end > start) {
            return std.fmt.parseInt(u32, stdout[start..end], 10) catch |err| {
                log.err("Error parsing CPU cores count: {}\n", .{err});
                return err;
            };
        }
    }
    
    return error.CouldNotFindNumCores;
}

pub fn getTotalMemory(allocator: std.mem.Allocator) !u64 {
    // Use provided allocator for WMIC command execution
    const output = try exec(allocator, &.{ "wmic", "ComputerSystem", "get", "TotalPhysicalMemory", "/format:value" });

    // Find TotalPhysicalMemory=X pattern
    if (std.mem.indexOf(u8, output, "TotalPhysicalMemory=")) |pos| {
        const start = pos + "TotalPhysicalMemory=".len;
        var end = start;
        while (end < output.len and std.ascii.isDigit(output[end])) : (end += 1) {}
        
        if (end > start) {
            return std.fmt.parseInt(u64, output[start..end], 10) catch |err| {
                log.err("Error parsing total memory size: {}\n", .{err});
                return err;
            };
        }
    }

    return error.CouldNotRetrieveMemorySize;
}

fn exec(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const stdout = (try std.process.Child.run(.{ .allocator = allocator, .argv = args })).stdout;

    if (stdout.len == 0) return error.EmptyOutput;

    return stdout[0 .. stdout.len - 1];
}
