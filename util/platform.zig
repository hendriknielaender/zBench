const std = @import("std");
const builtin = @import("builtin");

const lnx = @import("os/linux.zig");
const mac = @import("os/osx.zig");
const win = @import("os/windows.zig");

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
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try std.fmt.format(writer,
            \\  Operating System: {s}
            \\  CPU:              {s}
            \\  CPU Cores:        {d}
            \\  Total Memory:     {d:.3}
            \\
        , .{
            info.platform,
            info.cpu,
            info.cpu_cores,
            std.fmt.fmtIntSizeBin(info.memory_total),
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
    var scratch: [8192]u8 = undefined;
    var fbs = std.heap.FixedBufferAllocator.init(&scratch);
    const cpu = switch (builtin.os.tag) {
        .linux => try lnx.getCpuName(fbs.allocator()),
        .macos => try mac.getCpuName(fbs.allocator()),
        .windows => try win.getCpuName(fbs.allocator()),
        else => error.UnsupportedOs,
    };
    const len: usize = @min(cpu_name_buffer.len, cpu.len);
    std.mem.copyForwards(u8, cpu_name_buffer[0..len], cpu[0..len]);
    return cpu_name_buffer[0..len];
}

fn getCpuCores() !u32 {
    var scratch: [8192]u8 = undefined;
    var fbs = std.heap.FixedBufferAllocator.init(&scratch);
    return switch (builtin.os.tag) {
        .linux => try lnx.getCpuCores(fbs.allocator()),
        .macos => try mac.getCpuCores(fbs.allocator()),
        .windows => try win.getCpuCores(fbs.allocator()),
        else => error.UnsupportedOs,
    };
}

fn getTotalMemory() !u64 {
    var scratch: [8192]u8 = undefined;
    var fbs = std.heap.FixedBufferAllocator.init(&scratch);
    return switch (builtin.os.tag) {
        .linux => try lnx.getTotalMemory(fbs.allocator()),
        .macos => try mac.getTotalMemory(fbs.allocator()),
        .windows => try win.getTotalMemory(fbs.allocator()),
        else => error.UnsupportedOs,
    };
}

test "OsInfo" {
    // No allocator and no free needed, it's stored statically.
    const sysinfo = try getSystemInfo();
    try std.testing.expect(sysinfo.platform.len != 0);
    try std.testing.expect(sysinfo.cpu.len != 0);
    try std.testing.expect(0 < sysinfo.cpu_cores);
    try std.testing.expect(0 < sysinfo.memory_total);
}
