const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const meta_size = @byteOffsetOf(FrameNode, "payload");
pub const min_frame_size = ceilPowerOfTwo(usize, meta_size + 1);
pub const min_payload_size = min_frame_size - meta_size;

// https://github.com/ziglang/zig/issues/2426
fn ceilPowerOfTwo(comptime T: type, value: T) T {
    if (value <= 2) return value;
    const Shift = comptime std.math.Log2Int(T);
    return T(1) << @intCast(Shift, T.bit_count - @clz(T, value - 1));
}

fn isFrameSize(memsize: usize, comptime page_size: usize) bool {
    return memsize % page_size == 0 or memsize == std.math.floorPowerOfTwo(usize, memsize);
}

// Synthetic representation -- should not be created directly, but instead carved out of []u8 bytes
const FrameNode = packed struct {
    frame_size: usize,
    next: ?*FrameNode,
    // We can't embed arbitrarily sized arrays in a struct so stick a placeholder here
    payload: [@sizeOf(usize)]u8,

    pub fn init(raw_bytes: []u8) *FrameNode {
        const node = @ptrCast(*FrameNode, raw_bytes.ptr);
        node.frame_size = raw_bytes.len;
        node.next = null;
        node.validate() catch unreachable;
        return node;
    }

    pub fn cast(ptr: var) !*FrameNode {
        const node = @ptrCast(*FrameNode, ptr);
        try node.validate();
        return node;
    }

    pub fn restore(payload: [*]u8) !*FrameNode {
        return try FrameNode.cast(payload - @byteOffsetOf(FrameNode, "payload"));
    }

    pub fn validate(self: *FrameNode) !void {
        if (@ptrToInt(self) % min_frame_size != 0) {
            return error.UnalignedMemory;
        }
        if (!isFrameSize(self.frame_size, std.mem.page_size)) {
            return error.UnalignedMemory;
        }
    }

    pub fn payloadSize(self: *FrameNode) usize {
        return self.frame_size - meta_size;
    }

    pub fn payloadSlice(self: *FrameNode, start: usize, end: usize) []u8 {
        std.debug.assert(start <= end);
        std.debug.assert(end <= self.payloadSize());
        const ptr = @ptrCast([*]u8, &self.payload);
        return ptr[start..end];
    }
};

const FreeList = struct {
    first: ?*FrameNode,

    pub fn init() FreeList {
        return FreeList{ .first = null };
    }

    pub fn prepend(self: *FreeList, node: *FrameNode) void {
        node.next = self.first;
        self.first = node;
    }

    pub fn removeAfter(self: *FreeList, ref: ?*FrameNode) ?*FrameNode {
        const first_node = self.first orelse return null;
        if (ref) |ref_node| {
            const next_node = ref_node.next orelse return null;
            ref_node.next = next_node.next;
            return next_node;
        } else {
            self.first = first_node.next;
            return first_node;
        }
    }
};

const oversized_index = 0;
const page_index = 1;

pub const ZeeAllocDefaults = ZeeAlloc(std.mem.page_size);

pub fn ZeeAlloc(comptime page_size: usize) type {
    std.debug.assert(page_size >= std.mem.page_size);

    const inv_bitsize_ref = page_index + std.math.log2_int(usize, page_size);
    const size_buckets = inv_bitsize_ref - std.math.log2_int(usize, min_frame_size) + 1; // + 1 oversized list

    return struct {
        const Self = @This();

        backing_allocator: *Allocator,

        free_lists: [size_buckets]FreeList = [_]FreeList{FreeList.init()} ** size_buckets,
        page_size: usize = page_size,
        allocator: Allocator = Allocator{
            .reallocFn = realloc,
            .shrinkFn = shrink,
        },

        pub fn init(backing_allocator: *Allocator) Self {
            return Self{ .backing_allocator = backing_allocator };
        }

        fn allocNode(self: *Self, memsize: usize) !*FrameNode {
            const alloc_size = std.mem.alignForward(memsize + meta_size, page_size);
            const rawData = try self.backing_allocator.alignedAlloc(u8, page_size, alloc_size);
            return FrameNode.init(rawData);
        }

        fn findFreeNode(self: *Self, memsize: usize) ?*FrameNode {
            var search_size = self.padToFrameSize(memsize);

            while (true) : (search_size *= 2) {
                var i = self.freeListIndex(search_size);

                var free_list = &self.free_lists[i];
                var prev: ?*FrameNode = null;
                var iter = free_list.first;
                while (iter) |node| : ({
                    prev = iter;
                    iter = node.next;
                }) {
                    if (node.frame_size == search_size) {
                        const removed = free_list.removeAfter(prev);
                        std.debug.assert(removed == node);
                        return node;
                    }
                }

                if (i <= page_index) {
                    return null;
                }
            }
        }

        fn asMinimumData(self: *Self, node: *FrameNode, target_size: usize) []u8 {
            std.debug.assert(target_size <= node.payloadSize());

            const target_frame_size = self.padToFrameSize(target_size);

            var sub_frame_size = std.math.min(node.frame_size / 2, page_size);
            while (sub_frame_size >= target_frame_size) : (sub_frame_size /= 2) {
                const i = self.freeListIndex(sub_frame_size);
                const start = node.payloadSize() - sub_frame_size;
                const sub_frame_data = node.payloadSlice(start, node.payloadSize());
                const sub_node = FrameNode.init(sub_frame_data);
                self.free_lists[i].prepend(sub_node);
                node.frame_size = sub_frame_size;
            }

            return node.payloadSlice(0, target_size);
        }

        fn free(self: *Self, old_mem: []u8) []u8 {
            const node = FrameNode.restore(old_mem.ptr) catch unreachable;
            const i = self.freeListIndex(node.frame_size);
            self.free_lists[i].prepend(node);
            return old_mem[0..0];
        }

        fn padToFrameSize(self: *Self, memsize: usize) usize {
            const meta_memsize = memsize + meta_size;
            if (meta_memsize <= min_frame_size) {
                return min_frame_size;
            } else if (meta_memsize <= page_size) {
                return ceilPowerOfTwo(usize, meta_memsize);
            } else {
                return std.mem.alignForward(meta_memsize, page_size);
            }
        }

        fn freeListIndex(self: *Self, frame_size: usize) usize {
            std.debug.assert(isFrameSize(frame_size, page_size));
            if (frame_size > page_size) {
                return oversized_index;
            } else if (frame_size <= min_frame_size) {
                return self.free_lists.len - 1;
            } else {
                return inv_bitsize_ref - std.math.log2_int(usize, frame_size);
            }
        }

        fn realloc(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) Allocator.Error![]u8 {
            const self = @fieldParentPtr(Self, "allocator", allocator);
            if (new_align > min_frame_size) {
                return error.OutOfMemory;
            } else if (new_size <= old_mem.len) {
                const node = FrameNode.restore(old_mem.ptr) catch unreachable;
                return self.asMinimumData(node, new_size);
            } else {
                const node = self.findFreeNode(new_size) orelse try self.allocNode(new_size);

                const result = self.asMinimumData(node, new_size);

                if (old_mem.len > 0) {
                    std.mem.copy(u8, result, old_mem);
                    _ = self.free(old_mem);
                }
                return result[0..new_size];
            }
        }

        fn shrink(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) []u8 {
            const self = @fieldParentPtr(Self, "allocator", allocator);
            if (new_size == 0) {
                return self.free(old_mem);
            } else {
                const node = FrameNode.restore(old_mem.ptr) catch unreachable;
                return self.asMinimumData(node, new_size);
            }
        }

        fn debugCount(self: *Self, index: usize) usize {
            var count = usize(0);
            var iter = self.free_lists[index].first;
            while (iter) |node| : (iter = node.next) {
                count += 1;
            }
            return count;
        }

        fn debugCountAll(self: *Self) usize {
            var count = usize(0);
            for (self.free_lists) |_, i| {
                count += self.debugCount(i);
            }
            return count;
        }

        fn debugDump(self: *Self) void {
            for (self.free_lists) |_, i| {
                std.debug.warn("{}: {}\n", i, self.debugCount(i));
            }
        }
    };
}

// https://github.com/ziglang/zig/issues/2291
extern fn @"llvm.wasm.memory.grow.i32"(u32, u32) i32;
pub const wasm_allocator = init: {
    if (builtin.arch != .wasm32) {
        @compileError("WasmAllocator is only available for wasm32 arch");
    }

    // std.heap.wasm_allocator is designed for arbitrary sizing
    // We only need page sizing, and this lets us stay super small
    const WasmPageAllocator = struct {
        pub fn realloc(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) Allocator.Error![]u8 {
            std.debug.assert(old_mem.len == 0); // Shouldn't be actually reallocating
            std.debug.assert(new_size % std.mem.page_size == 0); // Should only be allocating page size chunks
            std.debug.assert(new_align == std.mem.page_size); // Should only align to page_size

            const requested_page_count = @intCast(u32, new_size / std.mem.page_size);
            const prev_page_count = @"llvm.wasm.memory.grow.i32"(0, requested_page_count);
            if (prev_page_count < 0) {
                return error.OutOfMemory;
            }

            const start_ptr = @intToPtr([*]u8, @intCast(usize, prev_page_count) * std.mem.page_size);
            return start_ptr[0..new_size];
        }

        pub fn shrink(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) []u8 {
            unreachable; // Shouldn't be shrinking / freeing
        }
    };

    var wasm_page_allocator = Allocator{
        .reallocFn = WasmPageAllocator.realloc,
        .shrinkFn = WasmPageAllocator.shrink,
    };
    var zee_allocator = ZeeAllocDefaults.init(&wasm_page_allocator);
    break :init &zee_allocator.allocator;
};

// Tests

const testing = std.testing;

test "ZeeAlloc helpers" {
    var buf: [0]u8 = undefined;
    var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(buf[0..]);
    var zee_alloc = ZeeAllocDefaults.init(&fixed_buffer_allocator.allocator);

    @"freeListIndex": {
        testing.expectEqual(usize(page_index), zee_alloc.freeListIndex(zee_alloc.page_size));
        testing.expectEqual(usize(page_index + 1), zee_alloc.freeListIndex(zee_alloc.page_size / 2));
        testing.expectEqual(usize(page_index + 2), zee_alloc.freeListIndex(zee_alloc.page_size / 4));
    }

    @"padToFrameSize": {
        testing.expectEqual(usize(zee_alloc.page_size), zee_alloc.padToFrameSize(zee_alloc.page_size - meta_size));
        testing.expectEqual(usize(2 * zee_alloc.page_size), zee_alloc.padToFrameSize(zee_alloc.page_size));
        testing.expectEqual(usize(2 * zee_alloc.page_size), zee_alloc.padToFrameSize(zee_alloc.page_size - meta_size + 1));
        testing.expectEqual(usize(3 * zee_alloc.page_size), zee_alloc.padToFrameSize(2 * zee_alloc.page_size));
    }
}

test "ZeeAlloc internals" {
    var buf: [1000000]u8 = undefined;

    @"node count makes sense": {
        var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(buf[0..]);
        var zee_alloc = ZeeAllocDefaults.init(&fixed_buffer_allocator.allocator);

        testing.expectEqual(zee_alloc.debugCountAll(), 0);

        var small1 = try zee_alloc.allocator.create(u8);
        var prev_free_nodes = zee_alloc.debugCountAll();
        testing.expect(prev_free_nodes > 0);

        var small2 = try zee_alloc.allocator.create(u8);
        testing.expectEqual(prev_free_nodes - 1, zee_alloc.debugCountAll());
        prev_free_nodes = zee_alloc.debugCountAll();

        zee_alloc.allocator.destroy(small2);
        testing.expectEqual(prev_free_nodes + 1, zee_alloc.debugCountAll());
        prev_free_nodes = zee_alloc.debugCountAll();

        var big1 = try zee_alloc.allocator.alloc(u8, 127 * 1024);
        testing.expectEqual(prev_free_nodes, zee_alloc.debugCountAll());
        zee_alloc.allocator.free(big1);
        testing.expectEqual(prev_free_nodes + 1, zee_alloc.debugCountAll());
        testing.expectEqual(usize(1), zee_alloc.debugCount(oversized_index));
    }
}

// -- functional tests from std/heap.zig

fn testAllocator(allocator: *std.mem.Allocator) !void {
    var slice = try allocator.alloc(*i32, 100);
    testing.expectEqual(slice.len, 100);
    for (slice) |*item, i| {
        item.* = try allocator.create(i32);
        item.*.* = @intCast(i32, i);
    }

    slice = try allocator.realloc(slice, 20000);
    testing.expectEqual(slice.len, 20000);

    for (slice[0..100]) |item, i| {
        testing.expectEqual(item.*, @intCast(i32, i));
        allocator.destroy(item);
    }

    slice = allocator.shrink(slice, 50);
    testing.expectEqual(slice.len, 50);
    slice = allocator.shrink(slice, 25);
    testing.expectEqual(slice.len, 25);
    slice = allocator.shrink(slice, 0);
    testing.expectEqual(slice.len, 0);
    slice = try allocator.realloc(slice, 10);
    testing.expectEqual(slice.len, 10);

    allocator.free(slice);
}

fn testAllocatorAligned(allocator: *Allocator, comptime alignment: u29) !void {
    // initial
    var slice = try allocator.alignedAlloc(u8, alignment, 10);
    testing.expectEqual(slice.len, 10);
    // grow
    slice = try allocator.realloc(slice, 100);
    testing.expectEqual(slice.len, 100);
    // shrink
    slice = allocator.shrink(slice, 10);
    testing.expectEqual(slice.len, 10);
    // go to zero
    slice = allocator.shrink(slice, 0);
    testing.expectEqual(slice.len, 0);
    // realloc from zero
    slice = try allocator.realloc(slice, 100);
    testing.expectEqual(slice.len, 100);
    // shrink with shrink
    slice = allocator.shrink(slice, 10);
    testing.expectEqual(slice.len, 10);
    // shrink to zero
    slice = allocator.shrink(slice, 0);
    testing.expectEqual(slice.len, 0);
}

fn testAllocatorLargeAlignment(allocator: *Allocator) Allocator.Error!void {
    //Maybe a platform's page_size is actually the same as or
    //  very near usize?

    // TODO: support ultra wide alignment (bigger than page_size)
    //if (std.mem.page_size << 2 > std.math.maxInt(usize)) return;

    //const USizeShift = @IntType(false, std.math.log2(usize.bit_count));
    //const large_align = u29(std.mem.page_size << 2);
    const USizeShift = @IntType(false, std.math.log2(usize.bit_count));
    const large_align = u29(std.mem.page_size);

    var align_mask: usize = undefined;
    _ = @shlWithOverflow(usize, ~usize(0), USizeShift(@ctz(usize, large_align)), &align_mask);

    var slice = try allocator.alignedAlloc(u8, large_align, 500);
    testing.expectEqual(@ptrToInt(slice.ptr) & align_mask, @ptrToInt(slice.ptr));

    slice = allocator.shrink(slice, 100);
    testing.expectEqual(@ptrToInt(slice.ptr) & align_mask, @ptrToInt(slice.ptr));

    slice = try allocator.realloc(slice, 5000);
    testing.expectEqual(@ptrToInt(slice.ptr) & align_mask, @ptrToInt(slice.ptr));

    slice = allocator.shrink(slice, 10);
    testing.expectEqual(@ptrToInt(slice.ptr) & align_mask, @ptrToInt(slice.ptr));

    slice = try allocator.realloc(slice, 20000);
    testing.expectEqual(@ptrToInt(slice.ptr) & align_mask, @ptrToInt(slice.ptr));

    allocator.free(slice);
}

fn testAllocatorAlignedShrink(allocator: *Allocator) Allocator.Error!void {
    var debug_buffer: [1000]u8 = undefined;
    const debug_allocator = &std.heap.FixedBufferAllocator.init(&debug_buffer).allocator;

    const alloc_size = std.mem.page_size * 2 + 50;
    var slice = try allocator.alignedAlloc(u8, 16, alloc_size);
    defer allocator.free(slice);

    var stuff_to_free = std.ArrayList([]align(16) u8).init(debug_allocator);
    // On Windows, VirtualAlloc returns addresses aligned to a 64K boundary,
    // which is 16 pages, hence the 32. This test may require to increase
    // the size of the allocations feeding the `allocator` parameter if they
    // fail, because of this high over-alignment we want to have.
    while (@ptrToInt(slice.ptr) == std.mem.alignForward(@ptrToInt(slice.ptr), std.mem.page_size * 32)) {
        try stuff_to_free.append(slice);
        slice = try allocator.alignedAlloc(u8, 16, alloc_size);
    }
    while (stuff_to_free.popOrNull()) |item| {
        allocator.free(item);
    }
    slice[0] = 0x12;
    slice[60] = 0x34;

    // realloc to a smaller size but with a larger alignment
    slice = try allocator.alignedRealloc(slice, std.mem.page_size, alloc_size / 2);
    testing.expectEqual(slice[0], 0x12);
    testing.expectEqual(slice[60], 0x34);
}

test "ZeeAlloc with FixedBufferAllocator" {
    var buf: [1000000]u8 = undefined;
    var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(buf[0..]);
    var zee_alloc = ZeeAllocDefaults.init(&fixed_buffer_allocator.allocator);

    try testAllocator(&zee_alloc.allocator);
    try testAllocatorAligned(&zee_alloc.allocator, 8);
    // try testAllocatorLargeAlignment(&zee_alloc.allocator);
    // try testAllocatorAlignedShrink(&zee_alloc.allocator);
}

test "ZeeAlloc with DirectAllocator" {
    var buf: [1000000]u8 = undefined;
    var zee_alloc = ZeeAllocDefaults.init(std.heap.direct_allocator);

    try testAllocator(&zee_alloc.allocator);
    try testAllocatorAligned(&zee_alloc.allocator, 8);
    // try testAllocatorLargeAlignment(&zee_alloc.allocator);
    // try testAllocatorAlignedShrink(&zee_alloc.allocator);
}

const bench = @import("bench.zig");
var test_buf: [1024 * 1024]u8 = undefined;
test "gc.benchmark" {
    try bench.benchmark(struct {
        const Arg = struct {
            num: usize,
            size: usize,

            fn benchAllocator(a: Arg, allocator: *Allocator, comptime free: bool) !void {
                var i: usize = 0;
                while (i < a.num) : (i += 1) {
                    const bytes = try allocator.alloc(u8, a.size);
                    defer if (free) allocator.free(bytes);
                }
            }
        };

        pub const args = [_]Arg{
            Arg{ .num = 10 * 1, .size = 1024 * 1 },
            Arg{ .num = 10 * 2, .size = 1024 * 1 },
            Arg{ .num = 10 * 4, .size = 1024 * 1 },
            Arg{ .num = 10 * 1, .size = 1024 * 2 },
            Arg{ .num = 10 * 2, .size = 1024 * 2 },
            Arg{ .num = 10 * 4, .size = 1024 * 2 },
            Arg{ .num = 10 * 1, .size = 1024 * 4 },
            Arg{ .num = 10 * 2, .size = 1024 * 4 },
            Arg{ .num = 10 * 4, .size = 1024 * 4 },
        };

        pub const iterations = 10000;

        pub fn FixedBufferAllocator(a: Arg) void {
            var fba = std.heap.FixedBufferAllocator.init(test_buf[0..]);
            a.benchAllocator(&fba.allocator, false) catch unreachable;
        }

        pub fn Arena_FixedBufferAllocator(a: Arg) void {
            var fba = std.heap.FixedBufferAllocator.init(test_buf[0..]);
            var arena = std.heap.ArenaAllocator.init(&fba.allocator);
            defer arena.deinit();

            a.benchAllocator(&arena.allocator, false) catch unreachable;
        }

        pub fn ZeeAlloc_FixedBufferAllocator(a: Arg) void {
            var fba = std.heap.FixedBufferAllocator.init(test_buf[0..]);
            var zee_alloc = ZeeAllocDefaults.init(&fba.allocator);

            a.benchAllocator(&zee_alloc.allocator, false) catch unreachable;
        }

        pub fn DirectAllocator(a: Arg) void {
            a.benchAllocator(std.heap.direct_allocator, true) catch unreachable;
        }

        pub fn Arena_DirectAllocator(a: Arg) void {
            var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
            defer arena.deinit();

            a.benchAllocator(&arena.allocator, false) catch unreachable;
        }

        pub fn ZeeAlloc_DirectAllocator(a: Arg) void {
            var zee_alloc = ZeeAllocDefaults.init(std.heap.direct_allocator);

            a.benchAllocator(&zee_alloc.allocator, false) catch unreachable;
        }
    });
}
