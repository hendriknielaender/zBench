const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const log = std.log.scoped(.zbench_platform_linux);

pub fn getCpuName(allocator: mem.Allocator) ![]const u8 {
    const file = try fs.cwd().openFile("/proc/cpuinfo", .{});
    defer file.close();
    var buf = try allocator.alloc(u8, 128); // TODO : [FO] I think we could use a fixed sized buffer here as well
    _ = try file.read(buf);
    const start = if (mem.indexOf(u8, buf, "model name")) |pos| pos + 13 else unreachable;
    const end = if (mem.indexOfScalar(u8, buf[start..], '\n')) |pos| start + pos else unreachable;
    return buf[start..end];
}

pub fn getCpuCores(allocator: mem.Allocator) !u32 {
    _ = allocator; // TODO : [FO] a fixed buffer should do here
    const file = try fs.cwd().openFile("/proc/cpuinfo", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var stream = buf_reader.reader();
    var buf: [128]u8 = undefined; // we do not need info from long lines

    // Count occurrences of "processor" to determine the number of cores
    var count: u32 = 0;
    while (true) {
        const line = stream.readUntilDelimiterOrEof(&buf, '\n') catch { // |err| {
            //            log.warn("read line error: {any}", .{err});
            // line might be too long; ignore
            continue;
        };
        if (line == null) break; // we reached EOF
        const pos = mem.indexOf(u8, line.?, "processor");
        if (pos != null) {
            count += 1;
            //           log.warn("found processor, count: {d}", .{count});
        }
    }

    return count;
}

pub fn getTotalMemory(allocator: std.mem.Allocator) !u64 {
    _ = allocator; // TODO : [FO] a fixed buffer should do here
    const file = try std.fs.cwd().openFile("/proc/meminfo", .{});
    defer file.close();

    var buf: [128]u8 = undefined;
    _ = try file.read(&buf); // anything above 128 bytes will be discarded
    // log.warn("bytes Read: {d}", .{bytesRead});

    var token_iterator = std.mem.tokenizeSequence(u8, &buf, "\n");
    while (token_iterator.next()) |line| {
        if (std.mem.startsWith(u8, line, "MemTotal:")) {
            // Extract the numeric value from the line
            var parts = std.mem.tokenizeSequence(u8, line, " ");
            var valueFound = false;
            while (parts.next()) |part| {
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
