const std = @import("std");
const builtin = @import("builtin");
const zee_alloc = @import("vendor/zee_alloc.zig");

const main = @import("main.zig");

const CYCLES_PER_MS = main.MHz / 1000;

const allocator = if (builtin.link_libc)
    std.heap.c_allocator
else if (builtin.arch.isWasm()) blk: {
    (zee_alloc.ExportC{
        .allocator = zee_alloc.ZeeAllocDefaults.wasm_allocator,
        .malloc = true,
        .free = true,
    }).run();
    break :blk zee_alloc.ZeeAllocDefaults.wasm_allocator;
} else {
    @compileError("No allocator found. Did you remember to link libc?");
};

/// Convert a slice into known memory representation -- enables C ABI
const U8Chunk = packed struct {
    const Int = @IntType(true, 2 * @bitSizeOf(usize));

    // TODO: remove floats
    // JS can't handle i64 yet so we're using f64 for now
    const Float = @Type(builtin.TypeInfo{ .Float = .{ .bits = 2 * @bitSizeOf(usize) } });
    const Abi = if (builtin.arch.isWasm()) Float else Int;

    ptr: [*]u8,
    len: usize,

    pub fn fromAbi(num: Abi) U8Chunk {
        return @bitCast(U8Chunk, num);
    }

    pub fn toAbi(self: U8Chunk) Abi {
        return @bitCast(Float, self);
    }

    pub fn fromSlice(slice: []u8) U8Chunk {
        return .{ .ptr = slice.ptr, .len = slice.len };
    }

    pub fn toSlice(self: U8Chunk) []u8 {
        return self.ptr[0..self.len];
    }
};

export fn fd_alloc() ?*main.Fundude {
    return allocator.create(main.Fundude) catch null;
}

export fn fd_init(fd: *main.Fundude, cart: U8Chunk.Abi) u8 {
    fd.mmu.load(U8Chunk.fromAbi(cart).toSlice()) catch |err| return switch (err) {
        error.CartTypeError => 1,
        error.RomSizeError => 2,
        error.RamSizeError => 3,
    };
    fd_reset(fd);
    return 0;
}

export fn fd_reset(fd: *main.Fundude) void {
    fd.mmu.reset();
    fd.video.reset();
    fd.cpu.reset();
    fd.inputs.reset();
    fd.timer.reset();
    fd.step_underflow = 0;
}

export fn fd_step(fd: *main.Fundude) i32 {
    // Reset tracking -- single step will always accrue negatives
    fd.step_underflow = 0;
    const cycles = fd_step_cycles(fd, 1);
    fd.step_underflow = 0;
    return cycles;
}

export fn fd_step_ms(fd: *main.Fundude, ms: f64) i32 {
    const cycles = @as(f64, ms) * CYCLES_PER_MS;
    std.debug.assert(cycles < std.math.maxInt(i32));
    return fd_step_cycles(fd, @floatToInt(i32, cycles));
}

export fn fd_step_cycles(fd: *main.Fundude, cycles: i32) i32 {
    if (fd.cpu.mode == .fatal) {
        return -9999;
    }

    const target_cycles: i32 = fd.step_underflow + cycles;
    var track = target_cycles;

    while (track >= 0) {
        const res = @call(.{ .modifier = .never_inline }, fd.cpu.step, .{&fd.mmu});
        std.debug.assert(res.duration > 0);

        @call(.{ .modifier = .never_inline }, fd.video.step, .{ &fd.mmu, res.duration });
        @call(.{ .modifier = .never_inline }, fd.timer.step, .{ &fd.mmu, res.duration });

        const pc_val = res.jump orelse fd.cpu.reg._16.get(.PC) + res.length;

        fd.cpu.reg._16.set(.PC, pc_val);

        track -= @intCast(i32, res.duration);

        if (fd.breakpoint == pc_val) {
            fd.step_underflow = 0;
            return target_cycles - track;
        }
    }

    fd.step_underflow = track;
    return target_cycles - track;
}

export fn fd_input_press(fd: *main.Fundude, input: u8) u8 {
    const changed = fd.inputs.press(&fd.mmu, .{ .raw = input });
    if (changed) {
        fd.cpu.mode = .norm;
        fd.mmu.dyn.io.IF.joypad = true;
    }
    return fd.inputs.raw;
}

export fn fd_input_release(fd: *main.Fundude, input: u8) u8 {
    _ = fd.inputs.release(&fd.mmu, .{ .raw = input });
    return fd.inputs.raw;
}

export fn fd_disassemble(fd: *main.Fundude) U8Chunk.Abi {
    if (fd.cpu.mode == .fatal) {
        return U8Chunk.fromSlice(&[_]u8{}).toAbi();
    }

    fd.mmu.dyn.io.boot_complete = 1;
    const addr = fd.cpu.reg._16.get(.PC);

    // TODO: explicitly decode
    const res = fd.cpu.opStep(&fd.mmu, fd.mmu.mbc.cart.ptr + addr);
    const new_addr = addr +% res.length;
    fd.cpu.reg._16.set(.PC, new_addr);

    if (new_addr >= std.math.min(fd.mmu.mbc.cart.len, 0x7FFF) or new_addr < addr) {
        fd.cpu.mode = .fatal;
    }
    std.mem.copy(u8, &fd.disassembly, res.name);
    return U8Chunk.fromSlice(fd.disassembly[0..res.name.len]).toAbi();
}

export fn fd_patterns_ptr(fd: *main.Fundude) *c_void {
    return &fd.video.cache.patterns.data;
}

export fn fd_background_ptr(fd: *main.Fundude) *c_void {
    return &fd.video.cache.background.data;
}

export fn fd_window_ptr(fd: *main.Fundude) *c_void {
    return &fd.video.cache.window.data;
}

export fn fd_sprites_ptr(fd: *main.Fundude) *c_void {
    return &fd.video.cache.sprites.data;
}

export fn fd_screen_ptr(fd: *main.Fundude) *c_void {
    return fd.video.screen.data.ptr;
}

export fn fd_cpu_reg(fd: *main.Fundude) U8Chunk.Abi {
    return U8Chunk.fromSlice(std.mem.asBytes(&fd.cpu.reg)).toAbi();
}

export fn fd_mmu(fd: *main.Fundude) U8Chunk.Abi {
    return U8Chunk.fromSlice(std.mem.asBytes(&fd.mmu.dyn)).toAbi();
}

export fn fd_set_breakpoint(fd: *main.Fundude, breakpoint: u16) void {
    fd.breakpoint = breakpoint;
}
