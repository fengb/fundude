const std = @import("std");
const base = @import("base.zig");

const c = @cImport({
    @cInclude("cpux.h");
    @cInclude("ggpx.h");
    @cInclude("irqx.h");
    @cInclude("mmux.h");
    @cInclude("ppux.h");
    @cInclude("timerx.h");
});

const CYCLES_PER_FRAME = (4 * 16742);

export fn fd_alloc() ?*base.Fundude {
    return std.heap.wasm_allocator.create(base.Fundude) catch null;
}

export fn fd_init(fd: *base.Fundude, cart_length: usize, cart: [*]u8) void {
    fd_reset(fd);
    fd.mmu.cart_length = cart_length;
    fd.mmu.cart = cart;
    fd.breakpoint = 0;
}

export fn fd_reset(fd: *base.Fundude) void {
    @memset(@ptrCast([*]u8, &fd.display), 0, @sizeOf(@typeOf(fd.display)));
    @memset(@ptrCast([*]u8, &fd.mmu.io), 0, @sizeOf(@typeOf(fd.mmu.io)));
    fd.cpu.PC._ = 0;
    fd.interrupt_master = false;
    fd.inputs = 0;
    fd.mode = .norm;
    fd.clock.cpu = 0;
    fd.clock.ppu = 0;
    fd.clock.timer = 0;
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

fn exec_step(fd: *base.Fundude) c.cpu_result {
    const res = c.irq_step(fd);
    if (res.duration > 0) {
        return res;
    }

    if (fd.mode == .halt) {
        return c.cpu_result{
            .jump = fd.cpu.PC._,
            .length = 0,
            .duration = 4,
            .zasm = c.zasm0(c"*SKIP"),
        };
    }
    return c.cpu_step(fd, c.mmu_ptr(&fd.mmu, fd.cpu.PC._));
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

        // c.ppu_step(fd, res.duration);
        // c.timer_step(fd, res.duration);

        fd.cpu.PC._ = res.jump;
        track -= @intCast(i32, res.duration);

        if (fd.breakpoint == fd.cpu.PC._) {
            fd.clock.cpu = 0;
            return adjusted_cycles - track;
        }
    }

    fd.clock.cpu = track;
    return adjusted_cycles + track;
}

export fn fd_input_press(fd: *base.Fundude, input: u8) u8 {
    const changed_to_true = (input ^ fd.inputs) ^ (~fd.inputs);
    if (changed_to_true != 0) {
        if (fd.mode == .stop) {
            fd.mode = .norm;
        }
        // fd.mmu.io.IF.joypad = true;
        fd.inputs |= input;
        c.ggp_sync(fd);
    }
    return fd.inputs;
}

export fn fd_input_release(fd: *base.Fundude, input: u8) u8 {
    fd.inputs &= ~input;
    c.ggp_sync(fd);
    return fd.inputs;
}

// export fn fd_disassemble(fd: *base.Fundude) ?[*c]u8 {
//     if (fd.mode == .fatal) {
//         return null;
//     }

//     fd.mmu.io.boot_complete = 1;
//     const addr = fd.cpu.PC._;

//     const res = c.cpu_step(fd, &fd.mmu.cart[addr]);

//     _ = c.zasm_puts(@ptrCast([*c]u8, &fd.disassembly), @sizeOf(@typeOf(fd.disassembly)), res.zasm);
//     fd.cpu.PC._ += res.length;

//     if (fd.cpu.PC._ >= fd.mmu.cart_length) {
//         fd.mode = .fatal;
//     }
//     return @ptrCast([*c]u8, &fd.disassembly);
// }

export fn fd_patterns_ptr(fd: *base.Fundude) *c_void {
    return &fd.patterns;
}

export fn fd_background_ptr(fd: *base.Fundude) *c_void {
    return &fd.background;
}

export fn fd_window_ptr(fd: *base.Fundude) *c_void {
    return &fd.window;
}

export fn fd_sprites_ptr(fd: *base.Fundude) *c_void {
    return &fd.sprites;
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
