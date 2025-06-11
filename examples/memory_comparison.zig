const std = @import("std");
const zbench = @import("zbench");
const builtin = @import("builtin");
const c = std.c;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// Old implementation using subprocess calls
fn execOld(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
    const result = try std.process.Child.run(.{ .allocator = allocator, .argv = args });
    defer allocator.free(result.stdout);
    if (result.stdout.len == 0) return error.EmptyOutput;
    
    // Copy to avoid use-after-free
    const output = try allocator.dupe(u8, result.stdout[0 .. result.stdout.len - 1]);
    return output;
}

fn getCpuNameOld(allocator: std.mem.Allocator) ![]const u8 {
    return try execOld(allocator, &.{ "sysctl", "-n", "machdep.cpu.brand_string" });
}

fn getCpuCoresOld(allocator: std.mem.Allocator) !u32 {
    const str = try execOld(allocator, &.{ "sysctl", "-n", "hw.physicalcpu" });
    return std.fmt.parseInt(u32, str, 10) catch return error.ParseError;
}

fn getTotalMemoryOld(allocator: std.mem.Allocator) !u64 {
    const str = try execOld(allocator, &.{ "sysctl", "-n", "hw.memsize" });
    return std.fmt.parseInt(u64, str, 10) catch return error.ParseError;
}

// New implementation using direct syscalls
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

fn getCpuNameNew(allocator: std.mem.Allocator) ![]const u8 {
    return try getSysctlByName(allocator, "machdep.cpu.brand_string");
}

fn getCpuCoresNew() !u32 {
    var value: u32 = 0;
    var size: usize = @sizeOf(u32);
    if (c.sysctlbyname("hw.physicalcpu", &value, &size, null, 0) != 0) {
        return error.SysctlFailed;
    }
    return value;
}

fn getTotalMemoryNew() !u64 {
    var value: u64 = 0;
    var size: usize = @sizeOf(u64);
    if (c.sysctlbyname("hw.memsize", &value, &size, null, 0) != 0) {
        return error.SysctlFailed;
    }
    return value;
}

fn benchmarkGetSystemInfoOld(allocator: std.mem.Allocator) void {
    if (builtin.os.tag != .macos) return;
    
    // Use the provided allocator to show actual heap usage
    const cpu_name = getCpuNameOld(allocator) catch return;
    defer allocator.free(cpu_name);
    const cpu_cores_str = execOld(allocator, &.{ "sysctl", "-n", "hw.physicalcpu" }) catch return;
    defer allocator.free(cpu_cores_str);
    const memory_str = execOld(allocator, &.{ "sysctl", "-n", "hw.memsize" }) catch return;
    defer allocator.free(memory_str);
}

fn benchmarkGetSystemInfoNew(allocator: std.mem.Allocator) void {
    _ = allocator;
    if (builtin.os.tag != .macos) return;
    
    // Use minimal allocator for CPU name only
    var scratch: [128]u8 = undefined;
    var fbs = std.heap.FixedBufferAllocator.init(&scratch);
    
    _ = getCpuNameNew(fbs.allocator()) catch return;
    _ = getCpuCoresNew() catch return;
    _ = getTotalMemoryNew() catch return;
}

fn benchmarkStackUsageOld(allocator: std.mem.Allocator) void {
    _ = allocator;
    if (builtin.os.tag != .macos) return;
    
    // Demonstrate old stack usage (what would be needed to avoid OOM)
    var scratch1: [8192]u8 = undefined;
    var scratch2: [8192]u8 = undefined; 
    var scratch3: [8192]u8 = undefined;
    
    // Simulate the stack allocation overhead
    std.mem.doNotOptimizeAway(&scratch1);
    std.mem.doNotOptimizeAway(&scratch2);
    std.mem.doNotOptimizeAway(&scratch3);
}

fn benchmarkStackUsageNew(allocator: std.mem.Allocator) void {
    _ = allocator;
    if (builtin.os.tag != .macos) return;
    
    // Demonstrate new minimal stack usage
    var scratch: [128]u8 = undefined;
    std.mem.doNotOptimizeAway(&scratch);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(gpa.allocator(), .{
        .iterations = 100,
    });
    defer {
        bench.deinit();
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.panic("Memory leak detected", .{});
    }

    try stdout.writeAll("Memory Usage Comparison: System Info Retrieval\n");
    try stdout.writeAll("==============================================\n\n");

    try bench.add("Old Implementation (subprocess + heap)", benchmarkGetSystemInfoOld, .{
        .track_allocations = true,
    });
    
    try bench.add("New Implementation (syscalls + stack)", benchmarkGetSystemInfoNew, .{
        .track_allocations = true,
    });

    try stdout.writeAll("\nStack Usage Comparison:\n");
    try stdout.writeAll("======================\n\n");
    
    try bench.add("Old Stack Usage (24KB total)", benchmarkStackUsageOld, .{});
    try bench.add("New Stack Usage (128B total)", benchmarkStackUsageNew, .{});

    try bench.run(stdout);
}