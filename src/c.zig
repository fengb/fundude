const std = @import("std");
const builtin = @import("builtin");
const zee_alloc = @import("vendor/zee_alloc.zig");

const Fundude = @import("main.zig");
const util = @import("util.zig");

const CYCLES_PER_MS = Fundude.MHz / 1000;

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
    // const Int = std.meta.IntType(true, 2 * @bitSizeOf(usize));
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

pub fn MatrixChunk(comptime T: type) type {
    return packed struct {
        const UsizeHalf = std.meta.IntType(true, @bitSizeOf(usize) / 2);
        const Abi = if (builtin.arch.isWasm()) U8Chunk.Abi else MatrixChunk(T);

        ptr: [*]T,
        width: UsizeHalf,
        height: UsizeHalf,

        pub fn fromMatrix(matrix: var) Abi {
            const M = std.meta.Child(@TypeOf(matrix.ptr));
            if (@sizeOf(M) != @sizeOf(T)) @compileError("Unsupported Matrix type: " ++ @typeName(M));

            const self = MatrixChunk(T){
                .ptr = @ptrCast([*]T, matrix.ptr),
                .width = @intCast(UsizeHalf, matrix.width),
                .height = @intCast(UsizeHalf, matrix.height),
            };
            return @bitCast(Abi, self);
        }

        pub fn toMatrix(raw: Abi) MatrixSlice(T) {
            const self = @bitCast(MatrixChunk(T), raw);
            return .{
                .data = self.ptr[0 .. self.width * self.height],
                .width = self.width,
                .height = self.height,
            };
        }
    };
}

export fn fd_init() ?*Fundude {
    return Fundude.init(allocator) catch return null;
}

export fn fd_deinit(fd: *Fundude) void {
    fd.deinit();
}

export fn fd_load(fd: *Fundude, cart: U8Chunk.Abi) i8 {
    fd.load(U8Chunk.toSlice(cart)) catch |err| return switch (err) {
        error.CartTypeError => 1,
        error.RomSizeError => 2,
        error.RamSizeError => 3,
    };
    return 0;
}

export fn fd_reset(fd: *Fundude) void {
    fd.reset();
}

export fn fd_step(fd: *Fundude) i8 {
    // Reset tracking -- single step will always accrue negatives
    fd.step_underflow = 0;
    return fd.step();
}

export fn fd_step_ms(fd: *Fundude, ms: f64) i32 {
    const cycles = @as(f64, ms) * CYCLES_PER_MS;
    std.debug.assert(cycles < std.math.maxInt(i32));
    return fd_step_cycles(fd, @floatToInt(i32, cycles));
}

export fn fd_step_cycles(fd: *Fundude, cycles: i32) i32 {
    const target_cycles: i32 = fd.step_underflow + cycles;
    var track = target_cycles;

    while (track >= 0) {
        track -= fd.step();

        if (fd.breakpoint == fd.cpu.reg._16.get(.PC)) {
            fd.step_underflow = 0;
            return target_cycles - track;
        }
    }

    fd.step_underflow = track;
    return target_cycles - track;
}

export fn fd_input_press(fd: *Fundude, input: u8) u8 {
    const changed = fd.inputs.press(&fd.mmu, .{ .raw = input });
    if (changed) {
        fd.cpu.mode = .norm;
        fd.mmu.dyn.io.IF.joypad = true;
    }
    return fd.inputs.raw;
}

export fn fd_input_release(fd: *Fundude, input: u8) u8 {
    _ = fd.inputs.release(&fd.mmu, .{ .raw = input });
    return fd.inputs.raw;
}

export fn fd_disassemble(buffer: *[16]u8, arg0: u8, arg1: u8, arg2: u8) U8Chunk.Abi {
    const op = Fundude.Cpu.Op.decode(.{ arg0, arg1, arg2 });
    return U8Chunk.fromSlice(op.disassemble(buffer) catch unreachable);
}

export fn fd_instr_len(arg0: u8) usize {
    const op = Fundude.Cpu.Op.decode(.{ arg0, 0, 0 });
    return op.length;
}

// Video
export fn fd_screen(fd: *Fundude) MatrixChunk(u16).Abi {
    return MatrixChunk(u16).fromMatrix(fd.video.screen().toSlice());
}

export fn fd_background(fd: *Fundude) MatrixChunk(u16).Abi {
    return MatrixChunk(u16).fromMatrix(fd.video.cache.background.data.toSlice());
}

export fn fd_window(fd: *Fundude) MatrixChunk(u16).Abi {
    return MatrixChunk(u16).fromMatrix(fd.video.cache.window.data.toSlice());
}

export fn fd_sprites(fd: *Fundude) MatrixChunk(u16).Abi {
    return MatrixChunk(u16).fromMatrix(fd.video.cache.sprites.data.toSlice());
}

export fn fd_patterns(fd: *Fundude) MatrixChunk(u8).Abi {
    return MatrixChunk(u8).fromMatrix(fd.video.cache.patterns.toMatrixSlice());
}

export fn fd_cpu_reg(fd: *Fundude) U8Chunk.Abi {
    return U8Chunk.fromSlice(std.mem.asBytes(&fd.cpu.reg));
}

/// Only expose the dynamic memory -- e.g. 0x8000 - 0xFFFF
export fn fd_mmu(fd: *Fundude) U8Chunk.Abi {
    return U8Chunk.fromSlice(std.mem.asBytes(&fd.mmu.dyn)[0x8000..]);
}

export fn fd_set_breakpoint(fd: *Fundude, breakpoint: u16) void {
    fd.breakpoint = breakpoint;
}
