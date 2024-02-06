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
