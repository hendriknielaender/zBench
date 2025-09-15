const std = @import("std");
const builtin = @import("builtin");

const lnx = @import("linux.zig");
const mac = @import("osx.zig");
const win = @import("windows.zig");

var cpu_name_buffer: [128]u8 = undefined;
var osinfo: ?OsInfo = null;

pub const OsInfo = struct {
    platform: []const u8,
    cpu: []const u8,
    cpu_cores: u32,
    memory_total: u64,
    // ... other system information

    pub fn format(
        info: OsInfo,
        writer: *std.Io.Writer,
    ) !void {
        try writer.print(
            \\  Operating System: {s}
            \\  CPU:              {s}
            \\  CPU Cores:        {d}
            \\  Total Memory:     {Bi:.3}
            \\
        , .{
            info.platform,
            info.cpu,
            info.cpu_cores,
            info.memory_total,
        });
    }
};

const platform = @tagName(builtin.os.tag) ++ " " ++ @tagName(builtin.cpu.arch);

pub fn getSystemInfo() !OsInfo {
    if (osinfo) |x| return x;
    osinfo = OsInfo{
        .platform = platform,
        .cpu = try getCpuName(),
        .cpu_cores = try getCpuCores(),
        .memory_total = try getTotalMemory(),
    };
    return osinfo.?;
}

fn getCpuName() ![]const u8 {
    switch (builtin.os.tag) {
        .linux => {
            const cpu_array = try lnx.getCpuName();
            const len = std.mem.indexOfScalar(u8, &cpu_array, 0) orelse cpu_array.len;
            const copy_len = @min(cpu_name_buffer.len, len);
            @memcpy(cpu_name_buffer[0..copy_len], cpu_array[0..copy_len]);
            return cpu_name_buffer[0..copy_len];
        },
        .macos => {
            const cpu_array = try mac.getCpuName();
            const len = std.mem.indexOfScalar(u8, &cpu_array, 0) orelse cpu_array.len;
            const copy_len = @min(cpu_name_buffer.len, len);
            @memcpy(cpu_name_buffer[0..copy_len], cpu_array[0..copy_len]);
            return cpu_name_buffer[0..copy_len];
        },
        .windows => {
            const cpu_array = try win.getCpuName();
            const len = std.mem.indexOfScalar(u8, &cpu_array, 0) orelse cpu_array.len;
            const copy_len = @min(cpu_name_buffer.len, len);
            @memcpy(cpu_name_buffer[0..copy_len], cpu_array[0..copy_len]);
            return cpu_name_buffer[0..copy_len];
        },
        else => return error.UnsupportedOs,
    }
}

fn getCpuCores() !u32 {
    return switch (builtin.os.tag) {
        .linux => try lnx.getCpuCores(),
        .macos => try mac.getCpuCores(),
        .windows => try win.getCpuCores(),
        else => error.UnsupportedOs,
    };
}

fn getTotalMemory() !u64 {
    return switch (builtin.os.tag) {
        .linux => try lnx.getTotalMemory(),
        .macos => try mac.getTotalMemory(),
        .windows => try win.getTotalMemory(),
        else => error.UnsupportedOs,
    };
}

test OsInfo {
    // No allocator and no free needed, it's stored statically.
    const sysinfo = try getSystemInfo();
    try std.testing.expect(sysinfo.platform.len != 0);
    try std.testing.expect(sysinfo.cpu.len != 0);
    try std.testing.expect(0 < sysinfo.cpu_cores);
    try std.testing.expect(0 < sysinfo.memory_total);
}
