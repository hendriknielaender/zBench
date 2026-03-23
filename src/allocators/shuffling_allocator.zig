//! A multi-threaded "shuffling" allocator for Zig,
//! implementing the standard `std.mem.Allocator` interface.
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// Constants: 32 rounded size classes, 256 spare objects per class.
const NUM_SIZE_CLASSES: usize = 32;
const SHUFFLE_CAPACITY: usize = 256;
const SHUFFLE_ALIGNMENT: std.mem.Alignment = std.mem.Alignment.of(usize);

comptime {
    assert(NUM_SIZE_CLASSES == 32);
    assert(SHUFFLE_CAPACITY == 256);
}

const SizeClassInfo = struct {
    index: usize,
    size_class: usize,
};

pub const ShufflingAllocator = struct {
    /// The IO interface used by the mutex implementation.
    io: std.Io,

    /// The underlying allocator we rely on for real memory requests.
    underlying: std.mem.Allocator,

    /// Global random state for picking shuffle indices.
    /// Accessed only while holding the `global_mutex`.
    rng_state: u64,

    /// One shuffle array per size class.
    size_classes: [NUM_SIZE_CLASSES]ShuffleArray,

    /// A mutex protecting the random state, and also each size class's
    /// shuffle array has its own sub-mutex. This lets us serialize the RNG
    /// while allowing independent size classes to proceed concurrently. So we do:
    ///
    ///   - Lock `global_mutex` while reading/writing `rng_state`.
    ///   - Lock `size_classes[i].mutex` while accessing that shuffle array.
    ///
    global_mutex: std.Io.Mutex,
    size_class_mutexes: [NUM_SIZE_CLASSES]std.Io.Mutex,

    pub fn create(
        io: std.Io,
        underlying: std.mem.Allocator,
        seed: u64,
    ) ShufflingAllocator {
        var self = ShufflingAllocator{
            .io = io,
            .underlying = underlying,
            .rng_state = seed,
            .size_classes = undefined,
            .global_mutex = .init,
            .size_class_mutexes = undefined,
        };

        // Zero-init each ShuffleArray (and each sub-mutex).
        inline for (0..NUM_SIZE_CLASSES) |i| {
            self.size_classes[i].init();
            self.size_class_mutexes[i] = .init;
        }

        return self;
    }

    pub fn deinit(self: *ShufflingAllocator) void {
        // Clean up all memory still in the shuffle arrays.
        inline for (0..NUM_SIZE_CLASSES) |i| {
            self.size_class_mutexes[i].lock(self.io) catch unreachable;
            defer self.size_class_mutexes[i].unlock(self.io);

            if (self.size_classes[i].active) {
                for (0..SHUFFLE_CAPACITY) |j| {
                    if (self.size_classes[i].ptrs[j]) |slot_ptr| {
                        std.mem.Allocator.rawFree(
                            self.underlying,
                            slot_ptr[0..self.size_classes[i].size_class],
                            SHUFFLE_ALIGNMENT,
                            @returnAddress(),
                        );
                        self.size_classes[i].ptrs[j] = null;
                    }
                }
                self.size_classes[i].active = false;
            }
        }
    }

    pub fn allocator(self: *ShufflingAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &ShufflingAllocator.vtable,
        };
    }

    fn random_index(self: *ShufflingAllocator, upper_bound: usize) usize {
        assert(upper_bound > 0);

        self.global_mutex.lock(self.io) catch unreachable;
        defer self.global_mutex.unlock(self.io);

        if (self.rng_state == 0) {
            self.rng_state = 0x9e3779b97f4a7c15;
        }

        // Marsaglia-style xorshift keeps the state machine simple and cheap.
        self.rng_state ^= self.rng_state << 13;
        self.rng_state ^= self.rng_state >> 7;
        self.rng_state ^= self.rng_state << 17;

        const product: u128 = @as(u128, self.rng_state) * upper_bound;
        return @intCast(product >> 64);
    }

    fn shuffling_array(
        self: *ShufflingAllocator,
        info: SizeClassInfo,
        ret_addr: usize,
    ) ?*ShuffleArray {
        const sc = &self.size_classes[info.index];

        if (sc.active) {
            assert(sc.size_class == info.size_class);
            return sc;
        }

        if (!sc.prefill(self.underlying, info.size_class, ret_addr)) {
            return null;
        }

        var i: usize = SHUFFLE_CAPACITY;
        while (i > 1) {
            i -= 1;
            const shuffle_index = self.random_index(i + 1);
            const tmp = sc.ptrs[i];
            sc.ptrs[i] = sc.ptrs[shuffle_index];
            sc.ptrs[shuffle_index] = tmp;
        }

        return sc;
    }

    /// The standard VTable with function pointers for Allocator calls.
    const vtable: std.mem.Allocator.VTable = .{
        .alloc = alloc_fn,
        .resize = resize_fn,
        .remap = remap_fn,
        .free = free_fn,
    };

    /// Actual .alloc method. Must return ?[]u8 or null on OOM.
    fn alloc_fn(
        self_ptr: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        assert((@intFromPtr(self_ptr) % @alignOf(ShufflingAllocator)) == 0);
        const tmp: *align(@alignOf(ShufflingAllocator)) anyopaque = @alignCast(self_ptr);
        const self: *ShufflingAllocator = @ptrCast(tmp);

        if (len == 0) return &[_]u8{};

        // Large alignments must bypass shuffling because this implementation
        // only maintains word-aligned spare objects
        if ((@as(u64, 1) << @intFromEnum(alignment)) > @alignOf(usize)) {
            return std.mem.Allocator.rawAlloc(
                self.underlying,
                len,
                alignment,
                ret_addr,
            );
        }

        const class_info = size_class_info(len) orelse {
            // Unsupported size => skip shuffling.
            return std.mem.Allocator.rawAlloc(
                self.underlying,
                len,
                alignment,
                ret_addr,
            );
        };

        self.size_class_mutexes[class_info.index].lock(self.io) catch unreachable;
        defer self.size_class_mutexes[class_info.index].unlock(self.io);

        const sc = self.shuffling_array(class_info, ret_addr) orelse {
            return std.mem.Allocator.rawAlloc(
                self.underlying,
                len,
                alignment,
                ret_addr,
            );
        };

        const replacement_ptr = std.mem.Allocator.rawAlloc(
            self.underlying,
            class_info.size_class,
            SHUFFLE_ALIGNMENT,
            ret_addr,
        ) orelse return null;

        const slot_index = self.random_index(SHUFFLE_CAPACITY);
        const shuffled_ptr = sc.ptrs[slot_index].?;
        sc.ptrs[slot_index] = replacement_ptr;

        return shuffled_ptr;
    }

    /// .free method.
    fn free_fn(
        self_ptr: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        assert((@intFromPtr(self_ptr) % @alignOf(ShufflingAllocator)) == 0);
        const tmp: *align(@alignOf(ShufflingAllocator)) anyopaque = @alignCast(self_ptr);
        const self: *ShufflingAllocator = @ptrCast(tmp);

        // Zero-length means nothing to free
        if (memory.len == 0) return;

        // Large alignments bypass shuffling for the same reason as alloc.
        if ((@as(u64, 1) << @intFromEnum(alignment)) > @alignOf(usize)) {
            std.mem.Allocator.rawFree(
                self.underlying,
                memory,
                alignment,
                ret_addr,
            );
            return;
        }

        const class_info = size_class_info(memory.len) orelse {
            // Unsupported size => skip shuffling.
            std.mem.Allocator.rawFree(
                self.underlying,
                memory,
                alignment,
                ret_addr,
            );
            return;
        };

        self.size_class_mutexes[class_info.index].lock(self.io) catch unreachable;
        defer self.size_class_mutexes[class_info.index].unlock(self.io);

        const sc = &self.size_classes[class_info.index];
        if (!sc.active) {
            std.mem.Allocator.rawFree(
                self.underlying,
                memory,
                alignment,
                ret_addr,
            );
            return;
        }

        assert(sc.size_class == class_info.size_class);

        const slot_index = self.random_index(SHUFFLE_CAPACITY);
        const evicted_ptr = sc.ptrs[slot_index].?;
        sc.ptrs[slot_index] = memory.ptr;

        std.mem.Allocator.rawFree(
            self.underlying,
            evicted_ptr[0..class_info.size_class],
            SHUFFLE_ALIGNMENT,
            ret_addr,
        );
    }

    /// .resize method: delegate only for layouts that were never shuffled.
    fn resize_fn(
        self_ptr: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        assert((@intFromPtr(self_ptr) % @alignOf(ShufflingAllocator)) == 0);
        const tmp: *align(@alignOf(ShufflingAllocator)) anyopaque = @alignCast(self_ptr);
        const self: *ShufflingAllocator = @ptrCast(tmp);

        if ((@as(u64, 1) << @intFromEnum(alignment)) > @alignOf(usize)) {
            return std.mem.Allocator.rawResize(
                self.underlying,
                memory,
                alignment,
                new_len,
                ret_addr,
            );
        }

        const class_info = size_class_info(memory.len) orelse {
            return std.mem.Allocator.rawResize(
                self.underlying,
                memory,
                alignment,
                new_len,
                ret_addr,
            );
        };

        self.size_class_mutexes[class_info.index].lock(self.io) catch unreachable;
        defer self.size_class_mutexes[class_info.index].unlock(self.io);

        if (!self.size_classes[class_info.index].active) {
            return std.mem.Allocator.rawResize(
                self.underlying,
                memory,
                alignment,
                new_len,
                ret_addr,
            );
        }

        // Shuffled allocations were rounded up to the size class, so we must
        // refuse in-place resize and let callers fall back to alloc-copy-free.
        return false;
    }

    /// .remap method: delegate only for layouts that were never shuffled.
    fn remap_fn(
        self_ptr: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) ?[*]u8 {
        assert((@intFromPtr(self_ptr) % @alignOf(ShufflingAllocator)) == 0);
        const tmp: *align(@alignOf(ShufflingAllocator)) anyopaque = @alignCast(self_ptr);
        const self: *ShufflingAllocator = @ptrCast(tmp);

        if ((@as(u64, 1) << @intFromEnum(alignment)) > @alignOf(usize)) {
            return std.mem.Allocator.rawRemap(
                self.underlying,
                memory,
                alignment,
                new_len,
                ret_addr,
            );
        }

        const class_info = size_class_info(memory.len) orelse {
            return std.mem.Allocator.rawRemap(
                self.underlying,
                memory,
                alignment,
                new_len,
                ret_addr,
            );
        };

        self.size_class_mutexes[class_info.index].lock(self.io) catch unreachable;
        defer self.size_class_mutexes[class_info.index].unlock(self.io);

        if (!self.size_classes[class_info.index].active) {
            return std.mem.Allocator.rawRemap(
                self.underlying,
                memory,
                alignment,
                new_len,
                ret_addr,
            );
        }

        return null;
    }
};

/// ShuffleArray keeps up to 256 pointers for each size class.
const ShuffleArray = struct {
    active: bool = false,
    size_class: usize = 0,
    ptrs: [SHUFFLE_CAPACITY]?[*]u8 = [_]?[*]u8{null} ** SHUFFLE_CAPACITY,

    fn init(self: *ShuffleArray) void {
        self.active = false;
        self.size_class = 0;
        // Zero out the pointer array:
        inline for (0..SHUFFLE_CAPACITY) |i| {
            self.ptrs[i] = null;
        }
    }

    fn prefill(
        self: *ShuffleArray,
        underlying: Allocator,
        size_class: usize,
        ret_addr: usize,
    ) bool {
        assert(!self.active);
        assert(size_class >= @sizeOf(usize));

        self.size_class = size_class;

        var slot_index: usize = 0;
        while (slot_index < SHUFFLE_CAPACITY) : (slot_index += 1) {
            const slot_ptr = std.mem.Allocator.rawAlloc(
                underlying,
                size_class,
                SHUFFLE_ALIGNMENT,
                ret_addr,
            ) orelse {
                while (slot_index > 0) {
                    slot_index -= 1;
                    const rollback_ptr = self.ptrs[slot_index].?;
                    std.mem.Allocator.rawFree(
                        underlying,
                        rollback_ptr[0..size_class],
                        SHUFFLE_ALIGNMENT,
                        ret_addr,
                    );
                    self.ptrs[slot_index] = null;
                }

                self.size_class = 0;
                return false;
            };

            self.ptrs[slot_index] = slot_ptr;
        }

        self.active = true;
        return true;
    }
};

/// Rounded size classes.
fn size_class_info(size: usize) ?SizeClassInfo {
    var size_class: usize = @sizeOf(usize);
    var stride: usize = @sizeOf(usize);
    var index: usize = 0;

    while (index < NUM_SIZE_CLASSES) : (index += 1) {
        if (size <= size_class) {
            return .{
                .index = index,
                .size_class = size_class,
            };
        }

        size_class += stride;
        if ((index + 1) % 4 == 0) {
            stride *= 2;
        }
    }

    return null;
}

test "multi-threaded shuffling allocator example usage" {
    // Just a simple single-thread test. For multi-thread usage,
    // you can launch threads that do `alloc` / `free` concurrently.
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const gpa = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(io, gpa, 12345);
    defer shuffler.deinit();
    const alloc = shuffler.allocator();

    const ptr = try alloc.alloc(u8, 16);
    defer alloc.free(ptr);

    for (ptr, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    for (ptr, 0..) |b, i| assert(b == i);
}

test "map" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const gpa = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(io, gpa, 42);
    defer shuffler.deinit();
    const alloc = shuffler.allocator();

    var hm = std.AutoHashMap(u32, u32).init(
        alloc,
    );
    defer hm.deinit();

    try hm.put(1, 2);
    try hm.put(5, 3);
    // done, dropping happens via `defer hm.deinit()`

    try std.testing.expectEqual(hm.get(1).?, 2);
    try std.testing.expectEqual(hm.get(5).?, 3);
}

test "strings" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const gpa = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(io, gpa, 123);
    defer shuffler.deinit();
    const alloc = shuffler.allocator();

    const text = try std.fmt.allocPrintSentinel(alloc, "foo, bar, {s}", .{"baz"}, 0);
    defer alloc.free(text);

    const want = "foo, bar, baz";
    try std.testing.expectEqualStrings(want, text);
}

test "test_larger_than_word_alignment" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const gpa = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(io, gpa, 0);
    defer shuffler.deinit();
    const alloc = shuffler.allocator();

    inline for (0..100) |_| {
        // Align to 32 bytes
        const ptr = try alloc.alignedAlloc(u8, .fromByteUnits(32), 1);
        defer alloc.free(ptr);

        assert(@intFromPtr(ptr.ptr) % 32 == 0);
        ptr[0] = 42;
    }
}

test "many_small_allocs" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const page_alloc = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(io, page_alloc, 12345);
    defer shuffler.deinit();
    const alloc = shuffler.allocator();

    const n = 16;
    const ptr_u32 = try alloc.alloc(u32, n);
    defer alloc.free(ptr_u32);

    // If we want to store loop index (usize) into a u32:
    for (ptr_u32, 0..) |*slot, i| {
        slot.* = @truncate(i);
    }
}

test "allocator view points at live shuffler storage" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    var shuffler = ShufflingAllocator.create(io, std.heap.page_allocator, 1);
    const alloc = shuffler.allocator();

    try std.testing.expectEqual(@intFromPtr(&shuffler), @intFromPtr(alloc.ptr));
}
