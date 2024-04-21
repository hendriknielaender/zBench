const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const log = std.log.scoped(.zbench_platform_linux);

pub fn getCpuName(allocator: std.mem.Allocator) ![]const u8 {
    const file = try fs.cwd().openFile("/proc/cpuinfo", .{});
    defer file.close();

    const buf = try allocator.alloc(u8, 1024);
    _ = try file.read(buf);

    const needle = "model name";
    const start = if (mem.indexOf(u8, buf, needle)) |pos|
        pos + needle.len + 3
    else
        return error.CouldNotFindCpuName;

    const len = if (mem.indexOfScalar(u8, buf[start..], '\n')) |pos|
        pos
    else
        return error.CouldNotFindCpuName;

    return buf[start..][0..len];
}

pub fn getCpuCores(allocator: std.mem.Allocator) !u32 {
    const file = try fs.cwd().openFile("/proc/cpuinfo", .{});
    defer file.close();

    const buf = try allocator.alloc(u8, 1024);
    _ = try file.read(buf);

    var token_iterator = std.mem.tokenizeSequence(u8, buf, "\n");
    while (token_iterator.next()) |line| {
        if (std.mem.startsWith(u8, line, "cpu cores")) {
            const start = if (mem.indexOf(u8, line, ":")) |pos| pos + 2 else 0;
            return std.fmt.parseInt(u32, line[start..], 10) catch |err| {
                log.err("Error parsing total memory size: {}\n", .{err});
                return err;
            };
        }
    }

    return error.CouldNotFindNumCores;
}

pub fn getTotalMemory(allocator: std.mem.Allocator) !u64 {
    const file = try std.fs.cwd().openFile("/proc/meminfo", .{});
    defer file.close();

    const buf: []u8 = try allocator.alloc(u8, 1024);
    _ = try file.read(buf);

    var token_iterator = std.mem.tokenizeSequence(u8, buf, "\n");
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
