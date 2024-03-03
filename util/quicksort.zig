const std = @import("std");
const builtin = std.builtin;
const expect = std.testing.expect;
const mem = std.mem;

pub fn sort(comptime T: type, array: []T, low: usize, high: usize) void {
    if (low >= high) {
        return;
    }

    const pivot_index = partition(T, array, low, high);

    if (pivot_index != 0) {
        sort(T, array, low, pivot_index - 1);
    }
    sort(T, array, pivot_index + 1, high);
}

fn partition(comptime T: type, array: []T, low: usize, high: usize) usize {
    const pivot = array[high];
    var i: usize = low; // Start `i` at `low` instead of `low - 1`.
    var j: usize = low;

    while (j < high) {
        if (array[j] <= pivot) {
            mem.swap(T, &array[i], &array[j]);
            i += 1;
        }
        j += 1;
    }

    mem.swap(T, &array[i], &array[high]);
    return i;
}

test "empty array" {
    const array: []u64 = &.{};
    sort(u64, array, 0, 0);
    const a = array.len;
    try expect(a == 0);
}

test "array with one element" {
    var array: [1]u64 = .{5};
    sort(u64, &array, 0, array.len - 1);
    const a = array.len;
    try expect(a == 1);
    try expect(array[0] == 5);
}

test "sorted array" {
    var array: [10]u64 = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    sort(u64, &array, 0, array.len - 1);
    for (array, 0..) |value, i| {
        try expect(value == (i + 1));
    }
}

test "reverse order" {
    var array: [10]u64 = .{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 };
    sort(u64, &array, 0, array.len - 1);
    for (array, 0..) |value, i| {
        try expect(value == (i + 1));
    }
}

test "unsorted array" {
    var array: [5]u64 = .{ 5, 3, 4, 1, 2 };
    sort(u64, &array, 0, array.len - 1);
    for (array, 0..) |value, i| {
        try expect(value == (i + 1));
    }
}

test "two last unordered" {
    var array: [10]u64 = .{ 1, 2, 3, 4, 5, 6, 7, 8, 10, 9 };
    sort(u64, &array, 0, array.len - 1);
    for (array, 0..) |value, i| {
        try expect(value == (i + 1));
    }
}

test "two first unordered" {
    var array: [10]u64 = .{ 2, 1, 3, 4, 5, 6, 7, 8, 9, 10 };
    sort(u64, &array, 0, array.len - 1);
    for (array, 0..) |value, i| {
        try expect(value == (i + 1));
    }
}

test "unordered" {
    comptime var nums = [_]u64{ 2, 3, 4, 6, 1, 8, 0, 5 };
    comptime sort(u64, &nums, 0, nums.len - 1);

    try std.testing.expectEqual([_]u64{ 0, 1, 2, 3, 4, 5, 6, 8 }, nums);
}
