const std = @import("std");
const builtin = @import("builtin");

const unix = @import("os/linux.zig");
const mac = @import("os/osx.zig");
const win = @import("os/windows.zig");

pub const OsInfo = struct {
    platform: []const u8,
    cpu: []const u8,
    cpu_cores: u32,
    memory_total: u64,
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
    return OsInfo{
        .platform = platform,
        .cpu = try unix.getCpuName(allocator),
        .cpu_cores = 1,
        .memory_total = 1,
    };
}

pub fn macos(allocator: std.mem.Allocator) !OsInfo {
    // sysctlbyname with "hw.ncpu" for CPU cores, "hw.memsize" for total memory
    return OsInfo{
        .platform = platform,
        .cpu = try mac.getCpuName(allocator),
        .cpu_cores = 1, // Retrieve CPU cores using sysctlbyname or similar,
        .memory_total = 1, // Retrieve total memory using sysctlbyname or similar,
    };
}

pub fn windows(allocator: std.mem.Allocator) !OsInfo {
    // GetSystemInfo, GlobalMemoryStatusEx, or similar for CPU cores and total memory
    return OsInfo{
        .platform = platform,
        .cpu = try win.getCpuName(allocator),
        .cpu_cores = 1, // Retrieve CPU cores using GetSystemInfo or similar,
        .memory_total = 1, // Retrieve total memory using GlobalMemoryStatusEx or similar,
    };
}
