const std = @import("std");
const builtin = @import("builtin");

const format = @import("format.zig");

const unix = @import("os/linux.zig");
const mac = @import("os/osx.zig");
const win = @import("os/windows.zig");

pub const OsInfo = struct {
    platform: []const u8,
    cpu: []const u8,
    cpu_cores: u32,
    memory_total: []const u8,
    // ... other system information
};

const platform = @tagName(builtin.os.tag) ++ " " ++ @tagName(builtin.cpu.arch);

pub fn getSystemInfo(allocator: std.mem.Allocator) !OsInfo {
    return switch (builtin.os.tag) {
        .linux => try linux(allocator),
        .macos => try macos(allocator),
        .windows => try windows(allocator),
        else => error.UnsupportedOs,
    };
}

pub fn linux(allocator: std.mem.Allocator) !OsInfo {
    const memory = try mac.getTotalMemory(allocator);

    return OsInfo{
        .platform = platform,
        .cpu = try unix.getCpuName(allocator),
        .cpu_cores = try unix.getCpuCores(allocator),
        .memory_total = try format.memorySize(memory, allocator),
    };
}

pub fn macos(allocator: std.mem.Allocator) !OsInfo {
    const memory = try mac.getTotalMemory(allocator);

    return OsInfo{
        .platform = platform,
        .cpu = try mac.getCpuName(allocator),
        .cpu_cores = try mac.getCpuCores(allocator),
        .memory_total = try format.memorySize(memory, allocator),
    };
}

pub fn windows(allocator: std.mem.Allocator) !OsInfo {
    const memory = try mac.getTotalMemory(allocator);

    return OsInfo{
        .platform = platform,
        .cpu = try win.getCpuName(allocator),
        .cpu_cores = try win.getCpuCores(allocator),
        .memory_total = try format.memorySize(memory, allocator),
    };
}
