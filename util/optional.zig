const std = @import("std");

/// Make every field of the struct T nullable.
pub fn Optional(comptime T: type) type {
    const T_info = switch (@typeInfo(T)) {
        .Struct => |x| x,
        else => @compileError("Optional only supports struct types for now"),
    };
    var fields: [T_info.fields.len]std.builtin.Type.StructField = undefined;
    for (T_info.fields, &fields) |fi, *fo| {
        fo.* = fi;
        fo.*.type = ?fi.type;
        fo.*.default_value = &@as(?fi.type, null);
    }
    var result = T_info;
    result.fields = &fields;
    return @Type(.{ .Struct = result });
}

/// Take any non-null fields from x, and any null fields are taken from y
/// instead.
pub fn optional(comptime T: type, x: Optional(T), y: T) T {
    const T_info = switch (@typeInfo(T)) {
        .Struct => |info| info,
        else => @compileError("Optional only supports struct types for now"),
    };
    var t: T = undefined;
    inline for (T_info.fields) |f|
        @field(t, f.name) =
            if (@field(x, f.name)) |xx| xx else @field(y, f.name);
    return t;
}

test "Optional" {
    const Foo = struct { abc: u8, xyz: u8 };
    const a: Foo = .{ .abc = 5, .xyz = 10 };
    const b: Foo = optional(Foo, .{ .abc = 6 }, a);
    try std.testing.expectEqual(@as(u8, 6), b.abc);
    try std.testing.expectEqual(@as(u8, 10), b.xyz);
}
