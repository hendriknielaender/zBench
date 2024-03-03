const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const log = std.log.scoped(.zbench_platform_linux);

pub fn getCpuName(allocator: mem.Allocator) ![]const u8 {
    const file = try fs.cwd().openFile("/proc/cpuinfo", .{});
    defer file.close();

    var buf: [128]u8 = undefined;
    _ = try file.read(&buf);

    const start = if (mem.indexOf(u8, &buf, "model name")) |pos| pos + 13 else 0;
    const end = if (mem.indexOfScalar(u8, buf[start..], '\n')) |pos| start + pos else 0;

    return if ((start == 0 and end == 0) or (start > end))
        error.CouldNotFindCpuName
    else
        allocator.dupe(u8, buf[start..end]);
}

pub fn getCpuCores() !u32 {
    const file = try fs.cwd().openFile("/proc/cpuinfo", .{});
    defer file.close();

    var buf: [1024]u8 = undefined;
    _ = try file.read(&buf);

    var token_iterator = std.mem.tokenizeSequence(u8, &buf, "\n");
    while (token_iterator.next()) |line| {
        if (std.mem.startsWith(u8, line, "cpu cores")) {
            const start = if (mem.indexOf(u8, line, ":")) |pos| pos + 2 else 0;
            return try std.fmt.parseInt(u32, line[start..], 10);
        }
    }

    return error.CouldNotFindNumCores;
}

pub fn getTotalMemory() !u64 {
    const file = try std.fs.cwd().openFile("/proc/meminfo", .{});
    defer file.close();

    var buf: [128]u8 = undefined;
    _ = try file.read(&buf);

    var token_iterator = std.mem.tokenizeSequence(u8, &buf, "\n");
    while (token_iterator.next()) |line| {
        if (std.mem.startsWith(u8, line, "MemTotal:")) {
            // Extract the numeric value from the line
            var parts = std.mem.tokenizeSequence(u8, line, " ");
            var valueFound = false;
            while (parts.next()) |part| {
                if (valueFound) {
                    // Convert the extracted value to bytes (from kB)
                    const memKb = try std.fmt.parseInt(u64, part, 10);
                    return memKb * 1024; // Convert kB to bytes
                }
                if (std.mem.eql(u8, part, "MemTotal:")) {
                    valueFound = true;
                }
            }
        }
    }

    return error.CouldNotFindMemoryTotal;
}
