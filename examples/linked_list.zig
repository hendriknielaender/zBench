const std = @import("std");
const zbench = @import("zbench");
const Benchmark = zbench.Benchmark;

// We can collect runners in a tuple like this to easily iterate over them
const runners = .{
    // Runner for appending 128 elements
    struct {
        const Self = @This();
        const name = "linked-list append-128";

        ll: LinkedList(i128),

        pub fn init(alloc: std.mem.Allocator) !Self {
            return Self { .ll = LinkedList(i128).init(alloc) };
        }

        pub fn run(self: *Self) void {
            for (0..128) |i| self.ll.append(i) catch @panic("Alloc error!");
        }

        pub fn deinit(self: *Self) void { self.ll.deinit(); }
    },

    // Runner for popping from list with 128 elements
    struct {
        const Self = @This();
        const name = "linked-list pop-128";

        ll: LinkedList(i128),

        pub fn init(alloc: std.mem.Allocator) !Self {
            var ll = LinkedList(i128).init(alloc);
            for (0..128) |i| ll.append(i) catch @panic("Alloc error!");
            return Self { .ll = ll };
        }

        pub fn run(self: *Self) void {
            for (0..128) |_| _ = self.ll.pop();
        }

        pub fn deinit(self: *Self) void { self.ll.deinit(); }
    },

    // Runner for iterating over a list with 128 elements and addint 1 to each element
    struct {
        const Self = @This();
        const name = "linked-list iter-128";

        ll: LinkedList(i128),

        pub fn init(alloc: std.mem.Allocator) !Self {
            var ll = LinkedList(i128).init(alloc);
            for (0..128) |i| ll.append(i) catch @panic("Alloc error!");
            return Self { .ll = ll};
        }

        pub fn run(self: *Self) void {
            var it = self.ll.iterStart();
            while (it.next()) |elem| {
                elem.* += 1;
            }
        }

        pub fn deinit(self: *Self) void { self.ll.deinit(); }
    },
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const runs: usize = 128;
    var bench = try Benchmark.init(1_000_000_000, runs, gpa.allocator());
    defer bench.deinit();

    zbench.prettyPrintHeader();
    inline for (runners) |Runner|
        try (try bench.runBench(Runner, Runner.name)).prettyPrint(false);
}

// Below lies a simple (and unfinished) doubly linked-list implementation
// Feel free to complete it and add more benchmarks!

fn Node(comptime T: type) type {
    return struct {
        const Self = @This();

        next: ?*Node(T),
        prev: ?*Node(T),
        val: T,
    };
}

fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        node: ?*Node(T),

        // NOTE: Should this return a pointer to the element? Unsure..
        pub fn next(self: *Self) ?*T {
            if (self.node) |node| {
                const ret = &node.val;
                self.node = node.next;

                return ret;
            } else {
                return null;
            }
        }

        pub fn prev(self: *Self) ?*T {
            if (self.node) |node| {
                const ret = &node.val;
                self.node = node.prev;

                return ret;
            } else {
                return null;
            }
        }
    };
}

/// Doubly linked list (not optimised)
pub fn LinkedList(comptime T: type) type {
    return struct {
        const Self = @This();
        const Allocator = @import("std").mem.Allocator;

        alloc: Allocator,
        head: ?*Node(T),
        tail: ?*Node(T),
        // curr: ?*Node(T),

        len: usize,

        fn getNodeAt(self: *const Self, idx: usize) ?*const Node(T) {
            if (idx >= self.len or idx < 0) {
                return null;
            }

            if (idx < self.len / 2) {
                var i: usize = 0;
                var node = self.head.?;
                while (true) : (i += 1) {
                    if (i == idx) break;
                    node = node.next.?;
                }
                return node;
            } else {
                var i: usize = self.len - 1;
                var node = self.tail.?;
                while (true) : (i -= 1) {
                    if (i == idx) break;
                    node = node.prev.?;
                }
                return node;
            }
        }

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .alloc = allocator,
                .head = null,
                .tail = null,
                //.curr = null,
                .len = 0,
            };
        }

        pub fn append(self: *Self, val: T) !void {
            if (self.len == 0) {
                self.head = try self.alloc.create(Node(T));
                self.head.?.* = Node(T){ .val = val, .next = null, .prev = null };

                self.tail = self.head.?;
            } else {
                const new_node = try self.alloc.create(Node(T));
                new_node.* = Node(T){ .val = val, .next = null, .prev = self.tail };
                self.tail.?.*.next = new_node;
                self.tail = new_node;
            }

            self.len += 1;
        }

        pub fn insert(self: *Self, val: T, idx: usize) !void {
            // TODO: Implement and benchmark me :(
            _ = val;
            _ = idx;
            _ = self;

            @panic("Not implemented");
        }

        pub fn appendSlice(self: *Self, items: []const T) !void {
            for (items) |item| {
                try self.append(item);
            }
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) {
                return null;
            }

            const ret = self.tail.?.*.val;
            const prev = self.tail.?.*.prev;
            self.alloc.destroy(self.tail.?);

            self.tail = prev;

            if (self.tail) |node| {
                node.next = null;
            } else {
                // We only hit this branch if the popped tail was the last node
                // so make sure to null out head as-well since the list is empty
                self.head = null;
            }

            self.len -= 1;
            return ret;
        }

        pub fn deinit(self: *Self) void {
            var node = if (self.head) |node| node else {
                return {};
            };

            while (node.next) |next| {
                self.alloc.destroy(node);
                node = next;
            }

            self.alloc.destroy(node);
        }

        pub fn iterStart(self: *Self) Iterator(T) {
            return Iterator(T){ .node = self.head };
        }

        pub fn iterEnd(self: *Self) Iterator(T) {
            return Iterator(T){ .node = self.tail };
        }
    };
}

// --- Unit tests --- //
const assert = @import("std").testing.expect;
const test_alloc = @import("std").testing.allocator;
const print = @import("std").debug.print;

test "list append" {
    var list = LinkedList(u8).init(test_alloc);
    try assert(list.len == 0);

    try list.append('a');
    try assert(list.len == 1 and list.head.?.*.val == 'a' and list.tail.?.*.val == 'a');

    try list.append('b');
    try assert(list.len == 2 and list.head.?.*.val == 'a' and list.tail.?.*.val == 'b');

    try list.append('c');
    try assert(list.len == 3 and list.head.?.*.val == 'a' and list.tail.?.*.val == 'c');

    list.deinit();
}

test "list iterator" {
    var list = LinkedList(u8).init(test_alloc);
    defer list.deinit();

    const alph = [_]u8{ 'a', 'b', 'c', 'd', 'e' };
    try list.appendSlice(&alph);

    var i: usize = 0;
    var iterf = list.iterStart();
    while (iterf.next()) |val| {
        try assert(val.* == alph[i]);
        i += 1;
    }

    try assert(i == alph.len);

    var iterb = list.iterEnd();
    while (iterb.prev()) |val| {
        i -= 1;
        try assert(val.* == alph[i]);
    }

    try assert(i == 0);
}

test "list get at index" {
    var list = LinkedList(u8).init(test_alloc);
    defer list.deinit();

    const alph = [_]u8{ 'a', 'b', 'c', 'd', 'e' };
    try list.appendSlice(&alph);

    for (0..alph.len) |i| {
        const val = if (list.getNodeAt(i)) |node| node.*.val else {
            @panic("");
        };
        //print("expected {d} | computed {d}\n", .{ alph[i], val });
        try assert(alph[i] == val);
    }
}

test "list pop" {
    var list = LinkedList(u8).init(test_alloc);
    defer list.deinit();

    const alph = [_]u8{ 'a', 'b', 'c', 'd', 'e' };
    try list.appendSlice(&alph);

    var i: usize = alph.len - 1;
    while (true) : (i -= 1) {
        const val = list.pop().?;
        //print("expected {d} | computed {d}\n", .{ alph[i], val });
        try assert(alph[i] == val);
        try assert(list.len == i);
        if (i == 0) break;
    }

    try assert(list.len == 0);
}
