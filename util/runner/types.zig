const std = @import("std");

pub const Error = std.mem.Allocator.Error;

pub const Step = enum { more };
