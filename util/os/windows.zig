const std = @import("std");
const log = std.log.scoped(.zbench_platform_windows);

pub fn getCpuName(allocator: std.mem.Allocator) ![]const u8 {
    const stdout = try exec(allocator, &.{ "wmic", "cpu", "get", "name" });

    // Ensure stdout is long enough before slicing
    if (stdout.len < 52) return error.InsufficientLength;

    return stdout[45 .. stdout.len - 7];
}

pub fn getCpuCores(allocator: std.mem.Allocator) !u32 {
    const stdout = try exec(allocator, &.{ "wmic", "cpu", "get", "NumberOfCores" });

    // Process the command output to extract the cores count
    // WMIC output has headers and multiple lines, we need to find the first digit occurrence
    var start: usize = 0;
    while (start < stdout.len and !std.ascii.isDigit(stdout[start])) : (start += 1) {}
    if (start == stdout.len) return error.InvalidData;

    var end = start;
    while (end < stdout.len and std.ascii.isDigit(stdout[end])) : (end += 1) {}

    // Parse the extracted string to an integer
    return std.fmt.parseInt(u32, stdout[start..end], 10) catch |err| {
        log.err("Error parsing CPU cores count: {}\n", .{err});
        return err;
    };
}

pub fn getTotalMemory(allocator: std.mem.Allocator) !u64 {
    // Execute the WMIC command to get total physical memory
    const output = try exec(allocator, &.{ "wmic", "ComputerSystem", "get", "TotalPhysicalMemory" });
    defer allocator.free(output);

    // Tokenize the output to find the numeric value
    var lines = std.mem.tokenize(u8, output, "\r\n");
    _ = lines.next(); // Skip the first line, which is the header

    // The second line contains the memory size in bytes
    if (lines.next()) |line| {
        // Trim spaces and parse the memory size
        const memSizeStr = std.mem.trim(u8, line, " \r\n\t");
        return std.fmt.parseInt(u64, memSizeStr, 10) catch |err| {
            log.err("Error parsing total memory size: {}\n", .{err});
            return err;
        };
    }

    return error.CouldNotRetrieveMemorySize;
}

fn exec(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const stdout = (try std.process.Child.run(.{ .allocator = allocator, .argv = args })).stdout;

    if (stdout.len == 0) return error.EmptyOutput;

    return stdout[0 .. stdout.len - 1];
}
