const std = @import("std");
const zee_alloc = @import("vendor/zee_alloc.zig");

const base = @import("base.zig");

const CYCLES_PER_FRAME = 70224;

const allocator = zee_alloc.ZeeAllocDefaults.wasm_allocator;

comptime {
    (zee_alloc.ExportC{
        .allocator = allocator,
        .malloc = true,
        .free = true,
    }).run();
}

export fn fd_alloc() ?*base.Fundude {
    return allocator.create(base.Fundude) catch null;
}

export fn fd_init(fd: *base.Fundude, cart_length: usize, cart: [*]u8) u8 {
    fd.mmu.load(cart[0..cart_length]) catch |err| return switch (err) {
        error.CartTypeError => 1,
        error.RomSizeError => 2,
        error.RamSizeError => 3,
    };
    fd_reset(fd);
    return 0;
}

export fn fd_reset(fd: *base.Fundude) void {
    fd.mmu.reset();
    fd.ppu.reset();
    fd.cpu.reset();
    fd.inputs._ = 0;
    fd.timer.reset();
    fd.clock.cpu = 0;
}

export fn fd_step(fd: *base.Fundude) i32 {
    // Reset tracking -- single step will always accrue negatives
    fd.clock.cpu = 0;
    const cycles = fd_step_cycles(fd, 1);
    fd.clock.cpu = 0;
    return cycles;
}

export fn fd_step_frame(fd: *base.Fundude) i32 {
    const start = fd_step_cycles(fd, CYCLES_PER_FRAME / 2);

    const remaining = if (!fd.mmu.dyn.io.ppu.LCDC.lcd_enable)
        CYCLES_PER_FRAME / 2
    else if (fd.ppu.clock < 30)
        0
    else
        CYCLES_PER_FRAME - fd.ppu.clock;

    return start + fd_step_cycles(fd, @intCast(i32, remaining));
}

export fn fd_step_frames(fd: *base.Fundude, frames: i16) i32 {
    var cycles: i32 = 0;

    var i: i16 = 0;
    while (i < frames) : (i += 1) {
        cycles += fd_step_frame(fd);
    }
    return cycles;
}

export fn fd_step_cycles(fd: *base.Fundude, cycles: i32) i32 {
    if (fd.cpu.mode == .fatal) {
        return -9999;
    }

    const adjusted_cycles: i32 = fd.clock.cpu + cycles;
    var track = adjusted_cycles;

    while (track >= 0) {
        const res = @call(.{ .modifier = .never_inline }, fd.cpu.step, .{&fd.mmu});
        std.debug.assert(res.duration > 0);

        @call(.{ .modifier = .never_inline }, fd.ppu.step, .{ &fd.mmu, res.duration });
        @call(.{ .modifier = .never_inline }, fd.timer.step, .{ &fd.mmu, res.duration });

        const pc_val = res.jump orelse fd.cpu.reg._16.get(.PC) + res.length;

        fd.cpu.reg._16.set(.PC, pc_val);

        track -= @intCast(i32, res.duration);

        if (fd.breakpoint == pc_val) {
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
        if (fd.cpu.mode == .stop) {
            fd.cpu.mode = .norm;
        }
        fd.mmu.dyn.io.IF.joypad = true;
        fd.inputs._ |= input;
        fd.inputs.update(&fd.mmu);
    }
    return fd.inputs._;
}

export fn fd_input_release(fd: *base.Fundude, input: u8) u8 {
    fd.inputs._ &= ~input;
    fd.inputs.update(&fd.mmu);
    return fd.inputs._;
}

export fn fd_disassemble(fd: *base.Fundude) ?[*]u8 {
    if (fd.cpu.mode == .fatal) {
        return null;
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
    fd.disassembly[res.name.len] = 0;
    return &fd.disassembly;
}

export fn fd_patterns_ptr(fd: *base.Fundude) *c_void {
    return &fd.ppu.cache.patterns.data;
}

export fn fd_background_ptr(fd: *base.Fundude) *c_void {
    return &fd.ppu.cache.background.data;
}

export fn fd_window_ptr(fd: *base.Fundude) *c_void {
    return &fd.ppu.cache.window.data;
}

export fn fd_sprites_ptr(fd: *base.Fundude) *c_void {
    return &fd.ppu.cache.sprites.data;
}

// TODO: rename?
export fn fd_cpu_ptr(fd: *base.Fundude) *c_void {
    return &fd.cpu.reg;
}

export fn fd_mmu_ptr(fd: *base.Fundude) *c_void {
    return &fd.mmu.dyn;
}

export fn fd_set_breakpoint(fd: *base.Fundude, breakpoint: u16) void {
    fd.breakpoint = breakpoint;
}
