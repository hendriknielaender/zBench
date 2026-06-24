const std = @import("std");

/// Make every field of the struct T nullable.
pub fn Partial(comptime T: type) type {
    const names = @typeInfo(T).@"struct".field_names;

    var types: [names.len]type = undefined;
    var attrs: [names.len]std.lang.Type.Struct.FieldAttributes =
        @splat(.{});

    inline for (names, 0..) |name, i| {
        const FieldType = @FieldType(T, name);

        types[i] = ?FieldType;
        attrs[i] = .{
            .default_value_ptr = &@as(?FieldType, null),
        };
    }

    return @Struct(
        .auto,
        null,
        names,
        &types,
        &attrs,
    );
}

/// Take any non-null fields from x, and any null fields are taken from y
/// instead.
pub fn partial(comptime T: type, x: Partial(T), y: T) T {
    var result = y;

    inline for (@typeInfo(T).@"struct".field_names) |name| {
        if (@field(x, name)) |value| {
            @field(result, name) = value;
        }
    }

    return result;
}

test partial {
    const Foo = struct { abc: u8, xyz: u8 };
    const a: Foo = .{ .abc = 5, .xyz = 10 };
    const b: Foo = partial(Foo, .{ .abc = 6 }, a);
    try std.testing.expectEqual(@as(u8, 6), b.abc);
    try std.testing.expectEqual(@as(u8, 10), b.xyz);
}
