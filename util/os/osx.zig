const std = @import("std");
const c = std.c;
const log = std.log.scoped(.zbench_platform_osx);

pub fn getCpuName() ![128:0]u8 {
    var result: [128:0]u8 = undefined;
    var size: usize = result.len;

    if (c.sysctlbyname("machdep.cpu.brand_string", &result, &size, null, 0) != 0) {
        return error.SysctlFailed;
    }

    // Ensure null termination
    if (size > 0 and size <= result.len) {
        if (result[size - 1] != 0) {
            result[size] = 0;
        }
    }

    return result;
}

pub fn getCpuCores() !u32 {
    var value: u32 = 0;
    var size: usize = @sizeOf(u32);

    if (c.sysctlbyname("hw.physicalcpu", &value, &size, null, 0) != 0) {
        return error.SysctlFailed;
    }

    return value;
}

pub fn getTotalMemory() !u64 {
    var value: u64 = 0;
    var size: usize = @sizeOf(u64);

    if (c.sysctlbyname("hw.memsize", &value, &size, null, 0) != 0) {
        return error.SysctlFailed;
    }

    return value;
}

fn getSysctlByName(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var size: usize = 0;

    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);

    if (c.sysctlbyname(name_z.ptr, null, &size, null, 0) != 0) {
        return error.SysctlFailed;
    }

    const buffer = try allocator.alloc(u8, size);

    if (c.sysctlbyname(name_z.ptr, buffer.ptr, &size, null, 0) != 0) {
        return error.SysctlFailed;
    }

    if (size > 0 and buffer[size - 1] == 0) {
        return buffer[0 .. size - 1];
    }

    return buffer[0..size];
}
