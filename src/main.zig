const std = @import("std");

const base = @import("base.zig");

const CYCLES_PER_FRAME = (4 * 16742);

export fn malloc(size: usize) ?*c_void {
    const result = std.heap.wasm_allocator.alloc(u8, size) catch return null;
    return result.ptr;
}

export fn free(c_ptr: *c_void) void {
    // TODO
}

export fn fd_alloc() ?*base.Fundude {
    return std.heap.wasm_allocator.create(base.Fundude) catch null;
}

export fn fd_init(fd: *base.Fundude, cart_length: usize, cart: [*]u8) void {
    fd_reset(fd);
    fd.mmu.cart = cart;
    fd.mmu.cart_length = cart_length;
    fd.breakpoint = 0;
}

export fn fd_reset(fd: *base.Fundude) void {
    fd.mmu.reset();
    fd.ppu.reset();
    fd.cpu.reset();
    fd.inputs._ = 0;
    fd.timer._ = 0;
    fd.mode = .norm;
    fd.clock.cpu = 0;
}

export fn fd_step(fd: *base.Fundude) i32 {
    // Reset tracking -- single step will always accrue negatives
    fd.clock.cpu = 0;
    const cycles = fd_step_cycles(fd, 1);
    fd.clock.cpu = 0;
    return cycles;
}

export fn fd_step_frames(fd: *base.Fundude, frames: i16) i16 {
    const cycles = fd_step_cycles(fd, i32(frames) * i32(CYCLES_PER_FRAME));
    return @intCast(i16, @divFloor(cycles, CYCLES_PER_FRAME));
}

fn exec_step(fd: *base.Fundude) base.cpu.Result {
    // const res = c.irq_step(fd);
    // if (res.duration > 0) {
    //     return res;
    // }
    if (fd.mode == .halt) {
        return base.cpu.Result{
            .name = "SKIP",
            .length = 0,
            .duration = 4,
        };
    }
    return fd.cpu.step(&fd.mmu, fd.mmu.ptr(fd.cpu.reg._16.PC._));
}

export fn fd_step_cycles(fd: *base.Fundude, cycles: i32) i32 {
    if (fd.mode == .fatal) {
        return -9999;
    }

    const adjusted_cycles: i32 = fd.clock.cpu + cycles;
    var track = adjusted_cycles;

    while (track >= 0) {
        const res = exec_step(fd);
        if (res.duration <= 0) {
            fd.mode = .fatal;
            return -9999;
        }

        fd.ppu.step(&fd.mmu, res.duration);
        fd.timer.step(&fd.mmu, res.duration);

        if (res.jump) |jump| {
            fd.cpu.reg._16.PC._ = jump;
        } else {
            fd.cpu.reg._16.PC._ += res.length;
        }
        track -= @intCast(i32, res.duration);

        if (fd.breakpoint == fd.cpu.reg._16.PC._) {
            fd.clock.cpu = 0;
            return adjusted_cycles - track;
        }
    }

    fd.clock.cpu = track;
    return adjusted_cycles + track;
}

export fn fd_input_press(fd: *base.Fundude, input: u8) u8 {
    const changed_to_true = (input ^ fd.inputs._) ^ (~fd.inputs._);
    if (changed_to_true != 0) {
        if (fd.mode == .stop) {
            fd.mode = .norm;
        }
        // fd.mmu.io.IF.joypad = true;
        fd.inputs._ |= input;
        fd.inputs.update(&fd.mmu.io.ggp);
    }
    return fd.inputs._;
}

export fn fd_input_release(fd: *base.Fundude, input: u8) u8 {
    fd.inputs._ &= ~input;
    fd.inputs.update(&fd.mmu.io.ggp);
    return fd.inputs._;
}

export fn fd_disassemble(fd: *base.Fundude) ?[*]u8 {
    if (fd.mode == .fatal) {
        return null;
    }

    fd.mmu.io.boot_complete = 1;
    const addr = fd.cpu.reg._16.PC._;

    const res = fd.cpu.step(&fd.mmu, fd.mmu.cart + addr);
    fd.cpu.reg._16.PC._ += res.length;

    if (fd.cpu.reg._16.PC._ >= fd.mmu.cart_length) {
        fd.mode = .fatal;
    }
    std.mem.copy(u8, fd.disassembly[0..], res.name);
    fd.disassembly[res.name.len] = 0;
    return fd.disassembly[0..].ptr;
}

export fn fd_patterns_ptr(fd: *base.Fundude) *c_void {
    return &fd.ppu.patterns;
}

export fn fd_background_ptr(fd: *base.Fundude) *c_void {
    return &fd.ppu.background;
}

export fn fd_window_ptr(fd: *base.Fundude) *c_void {
    return &fd.ppu.window;
}

export fn fd_sprites_ptr(fd: *base.Fundude) *c_void {
    return &fd.ppu.sprites;
}

export fn fd_cpu_ptr(fd: *base.Fundude) *c_void {
    return &fd.cpu;
}

export fn fd_mmu_ptr(fd: *base.Fundude) *c_void {
    return &fd.mmu;
}

export fn fd_set_breakpoint(fd: *base.Fundude, breakpoint: u16) void {
    fd.breakpoint = breakpoint;
}
