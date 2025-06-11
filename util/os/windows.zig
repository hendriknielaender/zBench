const std = @import("std");
const log = std.log.scoped(.zbench_platform_windows);

pub fn getCpuName(allocator: std.mem.Allocator) ![]const u8 {
    const stdout = try exec(allocator, &.{ "wmic", "cpu", "get", "name" });

    // Ensure stdout is long enough before slicing
    if (stdout.len < 52) return error.InsufficientLength;

    return stdout[45 .. stdout.len - 7];
}

pub fn getCpuCores() !u32 {
    // Use Windows API to get CPU core count directly
    const windows = std.os.windows;
    var system_info: windows.SYSTEM_INFO = undefined;
    windows.kernel32.GetSystemInfo(&system_info);
    return system_info.dwNumberOfProcessors;
}

pub fn getTotalMemory() !u64 {
    // Use Windows API to get total physical memory directly
    const windows = std.os.windows;
    var memory_status: windows.MEMORYSTATUSEX = undefined;
    memory_status.dwLength = @sizeOf(windows.MEMORYSTATUSEX);
    
    if (windows.kernel32.GlobalMemoryStatusEx(&memory_status) == 0) {
        return error.CouldNotRetrieveMemorySize;
    }
    
    return memory_status.ullTotalPhys;
}

fn exec(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const stdout = (try std.process.Child.run(.{ .allocator = allocator, .argv = args })).stdout;

    if (stdout.len == 0) return error.EmptyOutput;

    return stdout[0 .. stdout.len - 1];
}
