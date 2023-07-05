const clap = @import("clap");
const std = @import("std");
const builtin = @import("builtin");

const debug = std.debug;
const io = std.io;

const VERSION = "0.0.0";

const params = [_]clap.Param(clap.Help){
    clap.parseParam("-v, --verbose Display more...") catch unreachable,
    clap.parseParam("-h, --help Show help") catch unreachable,
    clap.parseParam("-n, --count <usize> How many runs? Default 10") catch unreachable,
    clap.parseParam("-f, --function <str> Function name to benchmark") catch unreachable,
    clap.parseParam("--version Print the version and exit") catch unreachable,
};

pub const Arguments = struct {
    verbose: bool,
    function: ?[]const u8,
    count: usize = 10,

    pub fn parse(allocator: std.mem.Allocator) !Arguments {
        var diag = clap.Diagnostic{};

        var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
            .diagnostic = &diag,
            .allocator = allocator,
        }) catch |err| {
            diag.report(io.getStdErr().writer(), err) catch {};
            return err;
        };

        defer res.deinit();

        if (res.args.version != 0) {
            std.debug.print("Version: {s}\n", .{VERSION});
        }

        return Arguments{ .verbose = res.args.verbose != 0, .function = res.args.function, .count = if (res.args.count) |c| c else 10 };
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args_result = try Arguments.parse(allocator);

    std.debug.print("verbose: {}\n", .{args_result.verbose});
    std.debug.print("count: {}\n", .{args_result.count});
    if (args_result.function) |function| {
        std.debug.print("function: {s}\n", .{function});
    } else {
        std.debug.print("function: None\n", .{});
    }
}
