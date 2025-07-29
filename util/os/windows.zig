const std = @import("std");
const log = std.log.scoped(.zbench_platform_windows);

// Windows API structures and functions
const DWORD = u32;
const DWORDLONG = u64;

const SYSTEM_INFO = extern struct {
    wProcessorArchitecture: u16,
    wReserved: u16,
    dwPageSize: DWORD,
    lpMinimumApplicationAddress: ?*anyopaque,
    lpMaximumApplicationAddress: ?*anyopaque,
    dwActiveProcessorMask: usize,
    dwNumberOfProcessors: DWORD,
    dwProcessorType: DWORD,
    dwAllocationGranularity: DWORD,
    wProcessorLevel: u16,
    wProcessorRevision: u16,
};

const MEMORYSTATUSEX = extern struct {
    dwLength: DWORD,
    dwMemoryLoad: DWORD,
    ullTotalPhys: DWORDLONG,
    ullAvailPhys: DWORDLONG,
    ullTotalPageFile: DWORDLONG,
    ullAvailPageFile: DWORDLONG,
    ullTotalVirtual: DWORDLONG,
    ullAvailVirtual: DWORDLONG,
    ullAvailExtendedVirtual: DWORDLONG,
};

extern "kernel32" fn GetSystemInfo(*SYSTEM_INFO) callconv(.winapi) void;
extern "kernel32" fn GlobalMemoryStatusEx(*MEMORYSTATUSEX) callconv(.winapi) std.os.windows.BOOL;

pub fn getCpuName() ![128:0]u8 {
    // Use the processor architecture info for now as a fallback
    var system_info: SYSTEM_INFO = undefined;
    GetSystemInfo(&system_info);

    const arch_name = switch (system_info.wProcessorArchitecture) {
        0 => "Intel x86",
        5 => "ARM",
        6 => "Intel Itanium-based",
        9 => "x64 (AMD or Intel)",
        12 => "ARM64",
        else => "Unknown Architecture",
    };

    var result: [128:0]u8 = undefined;
    const len = @min(result.len - 1, arch_name.len);
    @memcpy(result[0..len], arch_name[0..len]);
    result[len] = 0;

    return result;
}

pub fn getCpuCores() !u32 {
    var system_info: SYSTEM_INFO = undefined;
    GetSystemInfo(&system_info);
    return system_info.dwNumberOfProcessors;
}

pub fn getTotalMemory() !u64 {
    var memory_status: MEMORYSTATUSEX = undefined;
    memory_status.dwLength = @sizeOf(MEMORYSTATUSEX);

    if (GlobalMemoryStatusEx(&memory_status) == 0) {
        return error.CouldNotRetrieveMemorySize;
    }

    return memory_status.ullTotalPhys;
}

fn exec(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const stdout = (try std.process.Child.run(.{ .allocator = allocator, .argv = args })).stdout;

    if (stdout.len == 0) return error.EmptyOutput;

    return stdout[0 .. stdout.len - 1];
}
