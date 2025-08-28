const std = @import("std");

/// Make every field of the struct T nullable.
pub fn Partial(comptime T: type) type {
    const T_info = switch (@typeInfo(T)) {
        .@"struct" => |x| x,
        else => @compileError("Partial only supports struct types for now"),
    };
    var fields: [T_info.fields.len]std.builtin.Type.StructField = undefined;
    for (T_info.fields, &fields) |fi, *fo| {
        fo.* = fi;
        fo.*.type = ?fi.type;
        fo.*.default_value_ptr = &@as(?fi.type, null);
    }
    var result = T_info;
    result.fields = &fields;
    return @Type(.{ .@"struct" = result });
}

/// Take any non-null fields from x, and any null fields are taken from y
/// instead.
pub fn partial(comptime T: type, x: Partial(T), y: T) T {
    const T_info = switch (@typeInfo(T)) {
        .@"struct" => |info| info,
        else => @compileError("Partial only supports struct types for now"),
    };
    var t: T = undefined;
    inline for (T_info.fields) |f|
        @field(t, f.name) =
            if (@field(x, f.name)) |xx| xx else @field(y, f.name);
    return t;
}

test partial {
    const Foo = struct { abc: u8, xyz: u8 };
    const a: Foo = .{ .abc = 5, .xyz = 10 };
    const b: Foo = partial(Foo, .{ .abc = 6 }, a);
    try std.testing.expectEqual(@as(u8, 6), b.abc);
    try std.testing.expectEqual(@as(u8, 10), b.xyz);
}
