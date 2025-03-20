//! A multi-threaded "shuffling" allocator for Zig,
//! implementing the standard `std.mem.Allocator` interface.
const std = @import("std");
const Allocator = std.mem.Allocator;

/// Constants: 32 size classes, 256 shuffle capacity, etc.
const NUM_SIZE_CLASSES = 32;
const SHUFFLE_CAPACITY = 256;

pub const ShufflingAllocator = struct {
    /// .ptr is `*ShufflingAllocator`, .vtable are the function pointers below.
    base: std.mem.Allocator,

    /// The underlying allocator we rely on for real memory requests.
    underlying: std.mem.Allocator,

    /// Global random state for picking shuffle indices in [0..256).
    /// Accessed only while holding the `global_mutex`.
    rng_state: u64,

    /// One shuffle array per size class.
    size_classes: [NUM_SIZE_CLASSES]ShuffleArray,

    /// A mutex protecting the random state, and also each size class's
    /// shuffle array has its own sub‐mutex. This struct ensures we can lock
    /// a global mutex for the RNG, but a separate array of per‐class locks
    /// for concurrency on the shuffle arrays. So we do:
    ///
    ///   - Lock `global_mutex` while reading/writing `rng_state`.
    ///   - Lock `size_classes[i].mutex` while accessing that shuffle array.
    ///
    global_mutex: std.Thread.Mutex,
    size_class_mutexes: [NUM_SIZE_CLASSES]std.Thread.Mutex,

    pub fn create(
        underlying: std.mem.Allocator,
        seed: u64,
    ) ShufflingAllocator {
        var self = ShufflingAllocator{
            .base = .{ .ptr = undefined, .vtable = &ShufflingAllocator.vtable },
            .underlying = underlying,
            .rng_state = seed,
            .size_classes = undefined,
            .global_mutex = .{},
            .size_class_mutexes = undefined,
        };

        // Zero-init each ShuffleArray (and each sub-mutex).
        inline for (0..NUM_SIZE_CLASSES) |i| {
            self.size_classes[i].init();
            self.size_class_mutexes[i] = .{};
        }

        self.base.ptr = &self;

        return self;
    }

    pub fn deinit(self: *ShufflingAllocator) void {
        // Clean up all memory still in the shuffle arrays
        inline for (0..NUM_SIZE_CLASSES) |i| {
            self.size_class_mutexes[i].lock();
            defer self.size_class_mutexes[i].unlock();

            if (self.size_classes[i].active) {
                for (0..SHUFFLE_CAPACITY) |j| {
                    if (self.size_classes[i].ptrs[j]) |slot| {
                        std.mem.Allocator.rawFree(self.underlying, slot.ptr[0..self.size_classes[i].size_class], std.mem.Alignment.@"8", @returnAddress());
                        self.size_classes[i].ptrs[j] = null;
                    }
                }
                self.size_classes[i].active = false;
            }
        }
    }

    pub fn allocator(self: *ShufflingAllocator) Allocator {
        return self.base;
    }

    /// The standard VTable with function pointers for Allocator calls.
    const vtable: std.mem.Allocator.VTable = .{
        .alloc = allocFn,
        .resize = resizeFn,
        .remap = remapFn,
        .free = freeFn,
    };

    /// Actual .alloc method. Must return ?[]u8 or null on OOM.
    fn allocFn(
        self_ptr: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        std.debug.assert((@intFromPtr(self_ptr) % @alignOf(ShufflingAllocator)) == 0);
        const tmp: *align(@alignOf(ShufflingAllocator)) anyopaque = @alignCast(self_ptr);
        const self: *ShufflingAllocator = @ptrCast(tmp);

        if (len == 0) return &[_]u8{};

        // If alignment > size_of(usize), skip shuffling => fallback
        if ((@as(u64, 1) << @intFromEnum(alignment)) > @alignOf(usize)) {
            return std.mem.Allocator.rawAlloc(
                self.underlying,
                len,
                alignment,
                ret_addr,
            );
        }

        const idx_opt = sizeClassIndex(len);
        if (idx_opt == null) {
            // out-of-range => skip shuffling
            return std.mem.Allocator.rawAlloc(
                self.underlying,
                len,
                alignment,
                ret_addr,
            );
        }

        const class_index = idx_opt.?;
        self.size_class_mutexes[class_index].lock();
        defer self.size_class_mutexes[class_index].unlock();

        self.global_mutex.lock();
        const rand_i = randomIndex(&self.rng_state);
        self.global_mutex.unlock();

        const sc = &self.size_classes[class_index];
        sc.activateIfNeeded(len);

        // Allocate from underlying:
        const new_ptr = std.mem.Allocator.rawAlloc(
            self.underlying,
            len,
            alignment,
            ret_addr,
        ) orelse return null;

        // Create a new slot entry for this allocation
        const new_slot = SlotEntry{
            .ptr = new_ptr,
            .is_freed = false,
        };

        // Swap with the random slot:
        const old_entry = sc.ptrs[rand_i];

        // Replace the random slot with our new allocation
        sc.ptrs[rand_i] = new_slot;

        // If the random slot was empty, return the newly allocated pointer
        if (old_entry == null) {
            return new_ptr;
        }

        // Otherwise return the old pointer (which is now shuffled)
        return old_entry.?.ptr;
    }

    /// .free method.
    fn freeFn(
        self_ptr: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        std.debug.assert((@intFromPtr(self_ptr) % @alignOf(ShufflingAllocator)) == 0);
        const tmp: *align(@alignOf(ShufflingAllocator)) anyopaque = @alignCast(self_ptr);
        const self: *ShufflingAllocator = @ptrCast(tmp);

        // Zero-length means nothing to free
        if (memory.len == 0) return;

        // If alignment is large, skip shuffle
        if ((@as(u64, 1) << @intFromEnum(alignment)) > @alignOf(usize)) {
            std.mem.Allocator.rawFree(
                self.underlying,
                memory,
                alignment,
                ret_addr,
            );
            return;
        }

        const idx_opt = sizeClassIndex(memory.len);
        if (idx_opt == null) {
            // Out-of-range => skip shuffle
            std.mem.Allocator.rawFree(
                self.underlying,
                memory,
                alignment,
                ret_addr,
            );
            return;
        }

        const class_index = idx_opt.?;
        self.size_class_mutexes[class_index].lock();
        defer self.size_class_mutexes[class_index].unlock();

        const sc = &self.size_classes[class_index];
        if (!sc.active) {
            std.mem.Allocator.rawFree(
                self.underlying,
                memory,
                alignment,
                ret_addr,
            );
            return;
        }

        std.debug.assert(sc.size_class == memory.len);

        // Find the slot containing this memory
        var slot_index: ?usize = null;
        for (sc.ptrs, 0..) |entry, i| {
            if (entry) |slot| {
                if (slot.ptr == memory.ptr) {
                    slot_index = i;
                    break;
                }
            }
        }

        if (slot_index == null) {
            // Memory not found in our shuffle array, free directly
            std.mem.Allocator.rawFree(
                self.underlying,
                memory,
                alignment,
                ret_addr,
            );
            return;
        }

        std.mem.Allocator.rawFree(
            self.underlying,
            memory,
            alignment,
            ret_addr,
        );
        sc.ptrs[slot_index.?] = null;

        var freed_count: usize = 0;
        const max_to_free: usize = 4;

        for (sc.ptrs, 0..) |entry, i| {
            if (freed_count >= max_to_free) break;

            if (entry) |slot| {
                if (slot.is_freed) {
                    std.mem.Allocator.rawFree(
                        self.underlying,
                        slot.ptr[0..sc.size_class],
                        alignment,
                        ret_addr,
                    );
                    sc.ptrs[i] = null;
                    freed_count += 1;
                }
            }
        }
    }

    /// .resize method: pass-through, do not shuffle on resize.
    fn resizeFn(
        self_ptr: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        std.debug.assert((@intFromPtr(self_ptr) % @alignOf(ShufflingAllocator)) == 0);
        const tmp: *align(@alignOf(ShufflingAllocator)) anyopaque = @alignCast(self_ptr);
        const self: *ShufflingAllocator = @ptrCast(tmp);
        return std.mem.Allocator.rawResize(
            self.underlying,
            memory,
            alignment,
            new_len,
            ret_addr,
        );
    }

    /// .remap method: pass-through.
    fn remapFn(
        self_ptr: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) ?[*]u8 {
        std.debug.assert((@intFromPtr(self_ptr) % @alignOf(ShufflingAllocator)) == 0);
        const tmp: *align(@alignOf(ShufflingAllocator)) anyopaque = @alignCast(self_ptr);
        const self: *ShufflingAllocator = @ptrCast(tmp);
        return std.mem.Allocator.rawRemap(
            self.underlying,
            memory,
            alignment,
            new_len,
            ret_addr,
        );
    }
};

/// Entry for the shuffle array - includes pointer and free status
const SlotEntry = struct {
    ptr: [*]u8,
    is_freed: bool,
};

/// ShuffleArray keeps up to 256 pointers for each size class.
const ShuffleArray = struct {
    active: bool = false,
    size_class: usize = 0,
    ptrs: [SHUFFLE_CAPACITY]?SlotEntry = [_]?SlotEntry{null} ** SHUFFLE_CAPACITY,

    fn init(self: *ShuffleArray) void {
        self.active = false;
        self.size_class = 0;
        // Zero out the pointer array:
        inline for (0..SHUFFLE_CAPACITY) |i| {
            self.ptrs[i] = null;
        }
    }

    fn activateIfNeeded(self: *ShuffleArray, size: usize) void {
        if (!self.active) {
            self.active = true;
            self.size_class = size;
        } else {
            std.debug.assert(self.size_class == size);
        }
    }
};

/// Decide which size class to use, or return null if it doesn't fit.
fn sizeClassIndex(len: usize) ?usize {
    var c: usize = 8;
    var i: usize = 0;
    while (i < NUM_SIZE_CLASSES) : (i += 1) {
        if (len <= c) return i;
        c <<= 1; // next power-of-two
    }
    return null;
}

/// A linear congruential generator. We handle random state
/// with a single function to keep it minimal. We do not do recursion or
/// fancy abstractions, just a direct approach.
fn randomIndex(state_ptr: *u64) u8 {
    const mul = @mulWithOverflow(state_ptr.*, 6364136223846793005)[0];
    const add = @addWithOverflow(mul, 1)[0];
    state_ptr.* = add;

    return @truncate(add);
}

test "multi-threaded shuffling allocator example usage" {
    // Just a simple single-thread test. For multi-thread usage,
    // you can launch threads that do `alloc` / `free` concurrently.
    const gpa = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(gpa, 12345);
    defer shuffler.deinit();
    const alloc = shuffler.base;

    const ptr = try alloc.alloc(u8, 16);
    defer alloc.free(ptr);

    for (ptr, 0..) |*b, i| {
        b.* = @truncate(i);
    }

    for (ptr, 0..) |b, i| std.debug.assert(b == i);
}

test "map" {
    const gpa = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(gpa, 42);
    defer shuffler.deinit();
    const alloc = shuffler.base;

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
    const gpa = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(gpa, 123);
    defer shuffler.deinit();
    var alloc = shuffler.base;

    const text = try std.fmt.allocPrintZ(alloc, "foo, bar, {s}", .{"baz"});
    defer alloc.free(text);

    const want = "foo, bar, baz";
    try std.testing.expectEqualStrings(want, text);
}

test "test_larger_than_word_alignment" {
    const gpa = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(gpa, 0);
    defer shuffler.deinit();
    const alloc = shuffler.base;

    inline for (0..100) |_| {
        // Align to 32 bytes
        const ptr = try std.mem.Allocator.alignedAlloc(alloc, u8, 32, 1);
        defer alloc.free(ptr);

        std.debug.assert(@intFromPtr(ptr.ptr) % 32 == 0);
        ptr[0] = 42;
    }
}

test "many_small_allocs" {
    const page_alloc = std.heap.page_allocator;
    var shuffler = ShufflingAllocator.create(page_alloc, 12345);
    defer shuffler.deinit();
    const alloc = shuffler.base;

    const n = 16;
    const ptr_u32 = try alloc.alloc(u32, n);
    defer alloc.free(ptr_u32);

    // If we want to store loop index (usize) into a u32:
    for (ptr_u32, 0..) |*slot, i| {
        slot.* = @truncate(i);
    }
}
