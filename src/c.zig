const std = @import("std");
const builtin = @import("builtin");
const zee_alloc = @import("vendor/zee_alloc.zig");

const main = @import("main.zig");
const util = @import("util.zig");

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
pub const U8Chunk = packed struct {
    // TODO: switch floats to ints
    // JS can't handle i64 yet so we're using f64 for now
    // const Int = @IntType(true, 2 * @bitSizeOf(usize));
    const Float = @Type(builtin.TypeInfo{ .Float = .{ .bits = 2 * @bitSizeOf(usize) } });
    const Abi = if (builtin.arch.isWasm()) Float else U8Chunk;

    ptr: [*]u8,
    len: usize,

    pub fn toSlice(raw: Abi) []u8 {
        const self = @bitCast(U8Chunk, raw);
        return self.ptr[0..self.len];
    }

    pub fn fromSlice(slice: []u8) Abi {
        const self = U8Chunk{ .ptr = slice.ptr, .len = slice.len };
        return @bitCast(Abi, self);
    }
};

pub const U8MatrixChunk = packed struct {
    const UsizeHalf = @IntType(true, @bitSizeOf(usize) / 2);
    const Abi = if (builtin.arch.isWasm()) U8Chunk.Abi else U8MatrixChunk;

    ptr: [*]u8,
    width: UsizeHalf,
    height: UsizeHalf,

    pub fn fromMatrix(matrix: var) Abi {
        const T = std.meta.Child(@TypeOf(matrix.data));
        if (@sizeOf(T) != 1) @compileError("Unsupported Matrix type: " ++ @typeName(T));

        const self = U8MatrixChunk{
            .ptr = @ptrCast([*]u8, matrix.data.ptr),
            .width = @intCast(UsizeHalf, matrix.width),
            .height = @intCast(UsizeHalf, matrix.height),
        };
        return @bitCast(Abi, self);
    }

    pub fn toMatrix(raw: Abi) MatrixSlice(u8) {
        const self = @bitCast(U8MatrixChunk, raw);
        return .{
            .data = self.ptr[0 .. self.width * self.height],
            .width = self.width,
            .height = self.height,
        };
    }
};

export fn fd_alloc() ?*main.Fundude {
    return allocator.create(main.Fundude) catch null;
}

export fn fd_init(fd: *main.Fundude, cart: U8Chunk.Abi) u8 {
    fd.mmu.load(U8Chunk.toSlice(cart)) catch |err| return switch (err) {
        error.CartTypeError => 1,
        error.RomSizeError => 2,
        error.RamSizeError => 3,
    };
    fd_reset(fd);
    return 0;
}

export fn fd_reset(fd: *main.Fundude) void {
    fd.mmu.reset();
    fd.cpu.reset();
    fd.video.reset();
    fd.audio.reset();
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
        @call(.{ .modifier = .never_inline }, fd.audio.step, .{ &fd.mmu, res.duration });
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
        return U8Chunk.fromSlice(&[_]u8{});
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
    return U8Chunk.fromSlice(fd.disassembly[0..res.name.len]);
}

// Video
export fn fd_screen(fd: *main.Fundude) U8MatrixChunk.Abi {
    return U8MatrixChunk.fromMatrix(fd.video.screen);
}

export fn fd_background(fd: *main.Fundude) U8MatrixChunk.Abi {
    return U8MatrixChunk.fromMatrix(fd.video.cache.background.data.toSlice());
}

export fn fd_window(fd: *main.Fundude) U8MatrixChunk.Abi {
    return U8MatrixChunk.fromMatrix(fd.video.cache.window.data.toSlice());
}

export fn fd_sprites(fd: *main.Fundude) U8MatrixChunk.Abi {
    return U8MatrixChunk.fromMatrix(fd.video.cache.sprites.data.toSlice());
}

export fn fd_patterns(fd: *main.Fundude) U8MatrixChunk.Abi {
    return U8MatrixChunk.fromMatrix(fd.video.cache.patterns.toMatrixSlice());
}

export fn fd_cpu_reg(fd: *main.Fundude) U8Chunk.Abi {
    return U8Chunk.fromSlice(std.mem.asBytes(&fd.cpu.reg));
}

export fn fd_mmu(fd: *main.Fundude) U8Chunk.Abi {
    return U8Chunk.fromSlice(std.mem.asBytes(&fd.mmu.dyn));
}

export fn fd_set_breakpoint(fd: *main.Fundude, breakpoint: u16) void {
    fd.breakpoint = breakpoint;
}
