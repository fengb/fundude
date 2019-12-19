const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const meta_size = 2 * @sizeOf(usize);
const min_payload_size = meta_size;
const min_frame_size = meta_size + min_payload_size;

const jumbo_index = 0;
const page_index = 1;

pub const ZeeAllocDefaults = ZeeAlloc(Config{});

pub const Config = struct {
    /// ZeeAlloc will request a multiple of `page_size` from the backing allocator.
    /// **Must** be a power of two.
    page_size: usize = std.math.max(std.mem.page_size, 65536), // 64K ought to be enough for everybody
    validation: Validation = .External,

    jumbo_match_strategy: JumboMatchStrategy = .Closest,
    buddy_strategy: BuddyStrategy = .Fast,
    shrink_strategy: ShrinkStrategy = .Defer,

    pub const JumboMatchStrategy = enum {
        /// Use the frame that wastes the least space
        /// Scans the entire jumbo freelist, which is slower but keeps memory pretty tidy
        Closest,

        /// Use only exact matches
        /// -75 bytes vs `.Closest`
        /// Similar performance to Closest if allocation sizes are consistent throughout lifetime
        Exact,

        /// Use the first frame that fits
        /// -75 bytes vs `.Closest`
        /// Initially faster to allocate but causes major fragmentation issues
        First,
    };

    pub const BuddyStrategy = enum {
        /// Return the raw free frame immediately
        /// Generally faster because it does not recombine or resplit frames,
        /// but it also requires more underlying memory
        Fast,

        /// Recombine with free buddies to reclaim storage
        /// +153 bytes vs `.Fast`
        /// More efficient use of existing memory at the cost of cycles and bytes
        Coalesce,
    };

    pub const ShrinkStrategy = enum {
        /// Return a smaller view into the same frame
        /// Faster because it ignores shrink, but never reclaims space until freed
        Defer,

        /// Split the frame into smallest usable chunk
        /// +112 bytes vs `.Defer`
        /// Better at reclaiming non-jumbo memory, but never reclaims jumbo until freed
        Chunkify,

        /// Find and swap a replacement frame
        /// +295 bytes vs `.Defer`
        /// Reclaims all memory, but generally slower
        Swap,
    };

    pub const Validation = enum {
        /// Enable all validations, including library internals
        Dev,

        /// Only validate external boundaries — e.g. `realloc` or `free`
        External,

        /// Turn off all validations — pretend this library is `--release-small`
        Unsafe,

        fn useInternal(comptime self: Validation) bool {
            if (builtin.mode == .Debug) {
                return true;
            }
            return self == .Dev;
        }

        fn useExternal(comptime self: Validation) bool {
            return switch (builtin.mode) {
                .Debug => true,
                .ReleaseSafe => self == .Dev or self == .External,
                else => false,
            };
        }

        fn assertInternal(comptime self: Validation, ok: bool) void {
            @setRuntimeSafety(comptime self.useInternal());
            if (!ok) unreachable;
        }

        fn assertExternal(comptime self: Validation, ok: bool) void {
            @setRuntimeSafety(comptime self.useExternal());
            if (!ok) unreachable;
        }
    };
};

pub fn ZeeAlloc(comptime conf: Config) type {
    std.debug.assert(conf.page_size >= std.mem.page_size);
    std.debug.assert(std.math.isPowerOfTwo(conf.page_size));

    const inv_bitsize_ref = page_index + std.math.log2_int(usize, conf.page_size);
    const size_buckets = inv_bitsize_ref - std.math.log2_int(usize, min_frame_size) + 1; // + 1 jumbo list

    return struct {
        const Self = @This();

        const config = conf;

        // Synthetic representation -- should not be created directly, but instead carved out of []u8 bytes
        const Frame = packed struct {
            const alignment = 2 * @sizeOf(usize);
            const allocated_signal = @intToPtr(*Frame, std.math.maxInt(usize));

            next: ?*Frame,
            frame_size: usize,
            // We can't embed arbitrarily sized arrays in a struct so stick a placeholder here
            payload: [min_payload_size]u8,

            fn isCorrectSize(memsize: usize) bool {
                return memsize >= min_frame_size and (memsize % conf.page_size == 0 or std.math.isPowerOfTwo(memsize));
            }

            pub fn init(raw_bytes: []u8) *Frame {
                @setRuntimeSafety(comptime conf.validation.useInternal());
                const node = @ptrCast(*Frame, raw_bytes.ptr);
                node.frame_size = raw_bytes.len;
                node.validate() catch unreachable;
                return node;
            }

            pub fn restoreAddr(addr: usize) *Frame {
                @setRuntimeSafety(comptime conf.validation.useInternal());
                const node = @intToPtr(*Frame, addr);
                node.validate() catch unreachable;
                return node;
            }

            pub fn restorePayload(payload: [*]u8) !*Frame {
                @setRuntimeSafety(comptime conf.validation.useInternal());
                const node = @fieldParentPtr(Frame, "payload", @ptrCast(*[min_payload_size]u8, payload));
                try node.validate();
                return node;
            }

            pub fn validate(self: *Frame) !void {
                if (@ptrToInt(self) % alignment != 0) {
                    return error.UnalignedMemory;
                }
                if (!Frame.isCorrectSize(self.frame_size)) {
                    return error.UnalignedMemory;
                }
            }

            pub fn isAllocated(self: *Frame) bool {
                return self.next == allocated_signal;
            }

            pub fn markAllocated(self: *Frame) void {
                self.next = allocated_signal;
            }

            pub fn payloadSize(self: *Frame) usize {
                @setRuntimeSafety(comptime conf.validation.useInternal());
                return self.frame_size - meta_size;
            }

            pub fn payloadSlice(self: *Frame, start: usize, end: usize) []u8 {
                @setRuntimeSafety(comptime conf.validation.useInternal());
                conf.validation.assertInternal(start <= end);
                conf.validation.assertInternal(end <= self.payloadSize());
                const ptr = @ptrCast([*]u8, &self.payload);
                return ptr[start..end];
            }
        };

        const FreeList = packed struct {
            first: ?*Frame,

            pub fn init() FreeList {
                return FreeList{ .first = null };
            }

            pub fn root(self: *FreeList) *Frame {
                // Due to packed struct layout, FreeList.first == Frame.next
                // This enables more graceful iteration without needing a back reference.
                // Since this is not a full frame, accessing any other field will corrupt memory.
                // Thar be dragons 🐉
                return @ptrCast(*Frame, self);
            }

            pub fn prepend(self: *FreeList, node: *Frame) void {
                node.next = self.first;
                self.first = node;
            }

            pub fn remove(self: *FreeList, target: *Frame) !void {
                var iter = self.root();
                while (iter.next) |next| : (iter = next) {
                    if (next == target) {
                        _ = self.removeAfter(iter);
                        return;
                    }
                }

                return error.ElementNotFound;
            }

            pub fn removeAfter(self: *FreeList, ref: *Frame) *Frame {
                const next_node = ref.next.?;
                ref.next = next_node.next;
                return next_node;
            }
        };

        /// The definitive™ way of using `ZeeAlloc`
        pub const wasm_allocator = &_wasm.allocator;
        var _wasm = init(&wasm_page_allocator);

        backing_allocator: *Allocator,

        free_lists: [size_buckets]FreeList = [_]FreeList{FreeList.init()} ** size_buckets,
        allocator: Allocator = Allocator{
            .reallocFn = realloc,
            .shrinkFn = shrink,
        },

        pub fn init(backing_allocator: *Allocator) Self {
            return Self{ .backing_allocator = backing_allocator };
        }

        fn allocNode(self: *Self, memsize: usize) !*Frame {
            @setRuntimeSafety(comptime conf.validation.useInternal());
            const alloc_size = unsafeAlignForward(memsize + meta_size);
            const rawData = try self.backing_allocator.reallocFn(self.backing_allocator, &[_]u8{}, 0, alloc_size, conf.page_size);
            return Frame.init(rawData);
        }

        fn findFreeNode(self: *Self, memsize: usize) ?*Frame {
            @setRuntimeSafety(comptime conf.validation.useInternal());
            var search_size = self.padToFrameSize(memsize);

            while (true) : (search_size *= 2) {
                const i = self.freeListIndex(search_size);
                var free_list = &self.free_lists[i];

                var closest_match_prev: ?*Frame = null;
                var closest_match_size: usize = std.math.maxInt(usize);

                var iter = free_list.root();
                while (iter.next) |next| : (iter = next) {
                    switch (conf.jumbo_match_strategy) {
                        .Exact => {
                            if (next.frame_size == search_size) {
                                return free_list.removeAfter(iter);
                            }
                        },
                        .Closest => {
                            if (next.frame_size == search_size) {
                                return free_list.removeAfter(iter);
                            } else if (next.frame_size > search_size and next.frame_size < closest_match_size) {
                                closest_match_prev = iter;
                                closest_match_size = next.frame_size;
                            }
                        },
                        .First => {
                            if (next.frame_size >= search_size) {
                                return free_list.removeAfter(iter);
                            }
                        },
                    }
                }

                if (closest_match_prev) |prev| {
                    return free_list.removeAfter(prev);
                }

                if (i <= page_index) {
                    return null;
                }
            }
        }

        fn chunkify(self: *Self, node: *Frame, target_size: usize) []u8 {
            @setCold(config.shrink_strategy != .Defer);
            @setRuntimeSafety(comptime conf.validation.useInternal());
            conf.validation.assertInternal(target_size <= node.payloadSize());

            if (node.frame_size <= conf.page_size) {
                const target_frame_size = self.padToFrameSize(target_size);

                var sub_frame_size = node.frame_size / 2;
                while (sub_frame_size >= target_frame_size) : (sub_frame_size /= 2) {
                    const start = node.payloadSize() - sub_frame_size;
                    const sub_frame_data = node.payloadSlice(start, node.payloadSize());
                    const sub_node = Frame.init(sub_frame_data);
                    self.freeListOfSize(sub_frame_size).prepend(sub_node);
                    node.frame_size = sub_frame_size;
                }
            }

            return node.payloadSlice(0, target_size);
        }

        fn free(self: *Self, target: *Frame) void {
            @setCold(true);
            @setRuntimeSafety(comptime conf.validation.useInternal());
            var node = target;
            if (conf.buddy_strategy == .Coalesce) {
                while (node.frame_size < conf.page_size) : (node.frame_size *= 2) {
                    // 16: [0, 16], [32, 48]
                    // 32: [0, 32], [64, 96]
                    const node_addr = @ptrToInt(node);
                    const buddy_addr = node_addr ^ node.frame_size;

                    const buddy = Frame.restoreAddr(buddy_addr);
                    if (buddy.isAllocated() or buddy.frame_size != node.frame_size) {
                        break;
                    }

                    self.freeListOfSize(buddy.frame_size).remove(buddy) catch unreachable;

                    // Use the lowest address as the new root
                    node = Frame.restoreAddr(node_addr & buddy_addr);
                }
            }

            self.freeListOfSize(node.frame_size).prepend(node);
        }

        // https://github.com/ziglang/zig/issues/2426
        fn unsafeCeilPowerOfTwo(comptime T: type, value: T) T {
            @setRuntimeSafety(comptime conf.validation.useInternal());
            if (value <= 2) return value;
            const Shift = comptime std.math.Log2Int(T);
            return @as(T, 1) << @intCast(Shift, T.bit_count - @clz(T, value - 1));
        }

        fn unsafeLog2Int(comptime T: type, x: T) std.math.Log2Int(T) {
            @setRuntimeSafety(comptime conf.validation.useInternal());
            conf.validation.assertInternal(x != 0);
            return @intCast(std.math.Log2Int(T), T.bit_count - 1 - @clz(T, x));
        }

        fn unsafeAlignForward(size: usize) usize {
            @setRuntimeSafety(comptime conf.validation.useInternal());
            const forward = size + (conf.page_size - 1);
            return forward & ~(conf.page_size - 1);
        }

        fn padToFrameSize(self: *Self, memsize: usize) usize {
            @setRuntimeSafety(comptime conf.validation.useInternal());
            const meta_memsize = std.math.max(memsize + meta_size, min_frame_size);
            return std.math.min(unsafeCeilPowerOfTwo(usize, meta_memsize), unsafeAlignForward(meta_memsize));
            // More byte-efficient of this:
            // const meta_memsize = memsize + meta_size;
            // if (meta_memsize <= min_frame_size) {
            //     return min_frame_size;
            // } else if (meta_memsize < conf.page_size) {
            //     return ceilPowerOfTwo(usize, meta_memsize);
            // } else {
            //     return std.mem.alignForward(meta_memsize, conf.page_size);
            // }
        }

        fn freeListOfSize(self: *Self, frame_size: usize) *FreeList {
            @setRuntimeSafety(comptime conf.validation.useInternal());
            const i = self.freeListIndex(frame_size);
            return &self.free_lists[i];
        }

        fn freeListIndex(self: *Self, frame_size: usize) usize {
            @setRuntimeSafety(comptime conf.validation.useInternal());
            conf.validation.assertInternal(Frame.isCorrectSize(frame_size));
            return inv_bitsize_ref - std.math.min(inv_bitsize_ref, unsafeLog2Int(usize, frame_size));
            // More byte-efficient of this:
            // if (frame_size > conf.page_size) {
            //     return jumbo_index;
            // } else if (frame_size <= min_frame_size) {
            //     return self.free_lists.len - 1;
            // } else {
            //     return inv_bitsize_ref - unsafeLog2Int(usize, frame_size);
            // }
        }

        fn realloc(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) Allocator.Error![]u8 {
            const self = @fieldParentPtr(Self, "allocator", allocator);
            if (new_align > min_frame_size) {
                return error.OutOfMemory;
            }

            const current_node = if (old_mem.len == 0) null else blk: {
                @setRuntimeSafety(comptime conf.validation.useExternal());
                const node = Frame.restorePayload(old_mem.ptr) catch unreachable;
                if (new_size <= node.payloadSize()) {
                    switch (conf.shrink_strategy) {
                        .Defer => return node.payloadSlice(0, new_size),
                        .Chunkify => return self.chunkify(node, new_size),
                        .Swap => {
                            if (self.padToFrameSize(new_size) == node.frame_size) {
                                return node.payloadSlice(0, new_size);
                            }
                        },
                    }
                }
                break :blk node;
            };

            const new_node = self.findFreeNode(new_size) orelse try self.allocNode(new_size);
            new_node.markAllocated();
            const result = self.chunkify(new_node, new_size);

            if (current_node) |node| {
                if (conf.shrink_strategy == .Swap) {
                    std.mem.copy(u8, result, old_mem[0..std.math.min(old_mem.len, new_size)]);
                } else {
                    std.mem.copy(u8, result, old_mem);
                }
                self.free(node);
            }
            return result;
        }

        fn shrink(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) []u8 {
            const self = @fieldParentPtr(Self, "allocator", allocator);
            @setRuntimeSafety(comptime conf.validation.useExternal());
            const node = Frame.restorePayload(old_mem.ptr) catch unreachable;
            if (new_size == 0) {
                conf.validation.assertExternal(node.isAllocated());
                self.free(node);
                return &[_]u8{};
            } else switch (conf.shrink_strategy) {
                .Defer => return node.payloadSlice(0, new_size),
                .Chunkify => return self.chunkify(node, new_size),
                .Swap => return realloc(allocator, old_mem, old_align, new_size, new_align) catch self.chunkify(node, new_size),
            }
        }

        fn debugCount(self: *Self, index: usize) usize {
            var count: usize = 0;
            var iter = self.free_lists[index].first;
            while (iter) |node| : (iter = node.next) {
                count += 1;
            }
            return count;
        }

        fn debugCountAll(self: *Self) usize {
            var count: usize = 0;
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

fn assertIf(comptime run_assert: bool, ok: bool) void {
    @setRuntimeSafety(run_assert);
    if (!ok) unreachable;
}

// https://github.com/ziglang/zig/issues/2291
extern fn @"llvm.wasm.memory.grow.i32"(u32, u32) i32;
var wasm_page_allocator = init: {
    if (builtin.arch != .wasm32) {
        @compileError("wasm allocator is only available for wasm32 arch");
    }

    // std.heap.wasm_allocator is designed for arbitrary sizing
    // We only need page sizing, and this lets us stay super small
    const WasmPageAllocator = struct {
        pub fn realloc(allocator: *Allocator, old_mem: []u8, old_align: u29, new_size: usize, new_align: u29) Allocator.Error![]u8 {
            const is_debug = builtin.mode == .Debug;
            @setRuntimeSafety(is_debug);
            assertIf(is_debug, old_mem.len == 0); // Shouldn't be actually reallocating
            assertIf(is_debug, new_size % std.mem.page_size == 0); // Should only be allocating page size chunks
            assertIf(is_debug, new_align % std.mem.page_size == 0); // Should only align to page_size increments

            const requested_page_count = @intCast(u32, new_size / std.mem.page_size);
            const prev_page_count = @"llvm.wasm.memory.grow.i32"(0, requested_page_count);
            if (prev_page_count < 0) {
                return error.OutOfMemory;
            }

            const start_ptr = @intToPtr([*]u8, @intCast(usize, prev_page_count) * std.mem.page_size);
            return start_ptr[0..new_size];
        }
    };

    break :init Allocator{
        .reallocFn = WasmPageAllocator.realloc,
        .shrinkFn = undefined, // Shouldn't be shrinking / freeing
    };
};

pub const ExportC = struct {
    allocator: *std.mem.Allocator,
    malloc: bool = true,
    free: bool = true,
    calloc: bool = false,
    realloc: bool = false,

    pub fn run(comptime conf: ExportC) void {
        const Funcs = struct {
            extern fn malloc(size: usize) ?*c_void {
                if (size == 0) {
                    return null;
                }
                //const result = conf.allocator.alloc(u8, size) catch return null;
                const result = conf.allocator.reallocFn(conf.allocator, &[_]u8{}, 0, size, 1) catch return null;
                return result.ptr;
            }
            extern fn calloc(num_elements: usize, element_size: usize) ?*c_void {
                const size = num_elements *% element_size;
                const c_ptr = @noInlineCall(malloc, size);
                if (c_ptr) |ptr| {
                    const p = @ptrCast([*]u8, ptr);
                    @memset(p, 0, size);
                }
                return c_ptr;
            }
            extern fn realloc(c_ptr: ?*c_void, new_size: usize) ?*c_void {
                if (new_size == 0) {
                    @noInlineCall(free, c_ptr);
                    return null;
                } else if (c_ptr) |ptr| {
                    // Use a synthetic slice
                    const p = @ptrCast([*]u8, ptr);
                    //const result = conf.allocator.realloc(p[0..1], new_size) catch return null;
                    const result = conf.allocator.reallocFn(conf.allocator, p[0..1], 1, new_size, 1) catch return null;
                    return @ptrCast(*c_void, result.ptr);
                } else {
                    return @noInlineCall(malloc, new_size);
                }
            }
            extern fn free(c_ptr: ?*c_void) void {
                if (c_ptr) |ptr| {
                    // Use a synthetic slice. zee_alloc will free via corresponding metadata.
                    const p = @ptrCast([*]u8, ptr);
                    //conf.allocator.free(p[0..1]);
                    _ = conf.allocator.shrinkFn(conf.allocator, p[0..1], 1, 0, 0);
                }
            }
        };

        if (conf.malloc) {
            @export("malloc", Funcs.malloc, .Strong);
        }
        if (conf.calloc) {
            @export("calloc", Funcs.calloc, .Strong);
        }
        if (conf.realloc) {
            @export("realloc", Funcs.realloc, .Strong);
        }
        if (conf.free) {
            @export("free", Funcs.free, .Strong);
        }
    }
};

// Tests

const testing = std.testing;

test "ZeeAlloc helpers" {
    var buf: [0]u8 = undefined;
    var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(buf[0..]);
    var zee_alloc = ZeeAllocDefaults.init(&fixed_buffer_allocator.allocator);
    const page_size = ZeeAllocDefaults.config.page_size;

    @"freeListIndex": {
        testing.expectEqual(zee_alloc.freeListIndex(page_size), page_index);
        testing.expectEqual(zee_alloc.freeListIndex(page_size / 2), page_index + 1);
        testing.expectEqual(zee_alloc.freeListIndex(page_size / 4), page_index + 2);
    }

    @"padToFrameSize": {
        testing.expectEqual(zee_alloc.padToFrameSize(page_size - meta_size), page_size);
        testing.expectEqual(zee_alloc.padToFrameSize(page_size), 2 * page_size);
        testing.expectEqual(zee_alloc.padToFrameSize(page_size - meta_size + 1), 2 * page_size);
        testing.expectEqual(zee_alloc.padToFrameSize(2 * page_size), 3 * page_size);
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
        testing.expectEqual(zee_alloc.debugCountAll(), prev_free_nodes - 1);
        prev_free_nodes = zee_alloc.debugCountAll();

        var big1 = try zee_alloc.allocator.alloc(u8, 127 * 1024);
        testing.expectEqual(zee_alloc.debugCountAll(), prev_free_nodes);
        zee_alloc.allocator.free(big1);
        testing.expectEqual(zee_alloc.debugCountAll(), prev_free_nodes + 1);
        testing.expectEqual(zee_alloc.debugCount(jumbo_index), 1);
    }

    @"BuddyStrategy = Coalesce": {
        var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(buf[0..]);
        var zee_alloc = ZeeAlloc(Config{ .buddy_strategy = .Coalesce }).init(&fixed_buffer_allocator.allocator);

        var small = try zee_alloc.allocator.create(u8);
        testing.expect(zee_alloc.debugCountAll() > 1);
        zee_alloc.allocator.destroy(small);
        testing.expectEqual(zee_alloc.debugCountAll(), 1);
    }

    @"realloc reuses frame if possible": {
        var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(buf[0..]);
        var zee_alloc = ZeeAllocDefaults.init(&fixed_buffer_allocator.allocator);

        const orig = try zee_alloc.allocator.alloc(u8, 1);
        const addr = orig.ptr;

        var i: usize = 2;
        while (i <= min_payload_size) : (i += 1) {
            var re = try zee_alloc.allocator.realloc(orig, i);
            testing.expectEqual(re.ptr, addr);
        }
    }

    @"allocated_signal": {
        var fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(buf[0..]);
        var zee_alloc = ZeeAllocDefaults.init(&fixed_buffer_allocator.allocator);

        const payload = try zee_alloc.allocator.alloc(u8, 1);
        const frame = try ZeeAllocDefaults.Frame.restorePayload(payload.ptr);
        testing.expect(frame.isAllocated());

        zee_alloc.allocator.free(payload);
        testing.expect(!frame.isAllocated());
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
    const large_align: u29 = std.mem.page_size;

    var align_mask: usize = undefined;
    _ = @shlWithOverflow(usize, ~@as(usize, 0), @as(USizeShift, @ctz(usize, large_align)), &align_mask);

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
    var zee_alloc = ZeeAllocDefaults.init(std.heap.direct_allocator);

    try testAllocator(&zee_alloc.allocator);
    try testAllocatorAligned(&zee_alloc.allocator, 8);
    // try testAllocatorLargeAlignment(&zee_alloc.allocator);
    // try testAllocatorAlignedShrink(&zee_alloc.allocator);
}
