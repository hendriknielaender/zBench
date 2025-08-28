const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const log = std.log.scoped(.zbench_platform_linux);

pub fn getCpuName() ![128:0]u8 {
    const file = try fs.cwd().openFile("/proc/cpuinfo", .{});
    defer file.close();

    var buf: [1024]u8 = undefined;
    const bytes_read = try file.read(&buf);
    const content = buf[0..bytes_read];

    const needle = "model name";
    const start = if (mem.indexOf(u8, content, needle)) |pos|
        pos + needle.len + 3
    else
        return error.CouldNotFindCpuName;

    const len = if (mem.indexOfScalar(u8, content[start..], '\n')) |pos|
        pos
    else
        return error.CouldNotFindCpuName;

    const cpu_name = content[start..][0..len];

    var result: [128:0]u8 = undefined;
    const copy_len = @min(result.len - 1, len);
    @memcpy(result[0..copy_len], cpu_name[0..copy_len]);
    result[copy_len] = 0;

    return result;
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
            const trimmed = std.mem.trim(u8, line[start..], " \t\n\r");
            return std.fmt.parseInt(u32, trimmed, 10) catch |err| {
                log.err("Error parsing CPU cores count: {}\n", .{err});
                return err;
            };
        }
    }

    return error.CouldNotFindNumCores;
}

pub fn getTotalMemory() !u64 {
    const file = try std.fs.cwd().openFile("/proc/meminfo", .{});
    defer file.close();

    var buf: [1024]u8 = undefined;
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
