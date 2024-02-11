const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub fn getCpuName(allocator: mem.Allocator) ![]const u8 {
    const file = try fs.cwd().openFile("/proc/cpuinfo", .{});
    defer file.close();
    var buf = try allocator.alloc(u8, 128);
    _ = try file.read(buf);
    const start = if (mem.indexOf(u8, buf, "model name")) |pos| pos + 13 else unreachable;
    const end = if (mem.indexOfScalar(u8, buf[start..], '\n')) |pos| start + pos else unreachable;
    return buf[start..end];
}

pub fn getCpuCores(allocator: mem.Allocator) !u32 {
    const file = try fs.cwd().openFile("/proc/cpuinfo", .{});
    defer file.close();

    var buf = try allocator.alloc(u8, 128);
    const fileSize = try file.readAll(buf);
    buf = buf[0..fileSize];

    // Count occurrences of "processor" to determine the number of cores
    var count: u32 = 0;
    var pos: usize = 0;
    while (true) {
        const nextPos = mem.indexOf(u8, buf[pos..], "processor");
        if (nextPos) |foundPos| {
            count += 1;
            pos += foundPos + "processor".len;
        } else {
            break;
        }
    }

    return count;
}

pub fn getTotalMemory(allocator: std.mem.Allocator) !u64 {
    const file = try std.fs.cwd().openFile("/proc/meminfo", .{ .read = true });
    defer file.close();

    var buf = try allocator.alloc(u8, 128);
    const bytesRead = try file.read(buf);
    buf = buf[0..bytesRead];

    // Find the line that starts with "MemTotal"
    for (std.mem.tokenize(buf, "\n")) |line| {
        if (std.mem.startsWith(u8, line, "MemTotal:")) {
            // Extract the numeric value from the line
            const parts = std.mem.tokenize(line, " ");
            var valueFound = false;
            for (parts) |part| {
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
