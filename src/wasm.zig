const std = @import("std");
const zee_alloc = @import("vendor/zee_alloc.zig");

const base = @import("base.zig");

const CYCLES_PER_MS = base.MHz / 1000;

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
    fd.inputs.reset();
    fd.timer.reset();
    fd.step_underflow = 0;
}

export fn fd_step(fd: *base.Fundude) i32 {
    // Reset tracking -- single step will always accrue negatives
    fd.step_underflow = 0;
    const cycles = fd_step_cycles(fd, 1);
    fd.step_underflow = 0;
    return cycles;
}

export fn fd_step_ms(fd: *base.Fundude, ms: f64) i32 {
    const cycles = @as(f64, ms) * CYCLES_PER_MS;
    std.debug.assert(cycles < std.math.maxInt(i32));
    return fd_step_cycles(fd, @floatToInt(i32, cycles));
}

export fn fd_step_cycles(fd: *base.Fundude, cycles: i32) i32 {
    if (fd.cpu.mode == .fatal) {
        return -9999;
    }

    const target_cycles: i32 = fd.step_underflow + cycles;
    var track = target_cycles;

    while (track >= 0) {
        const res = @call(.{ .modifier = .never_inline }, fd.cpu.step, .{&fd.mmu});
        std.debug.assert(res.duration > 0);

        @call(.{ .modifier = .never_inline }, fd.ppu.step, .{ &fd.mmu, res.duration });
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

export fn fd_input_press(fd: *base.Fundude, input: u8) u8 {
    const changed = fd.inputs.press(&fd.mmu, .{ .raw = input });
    if (changed) {
        fd.cpu.mode = .norm;
        fd.mmu.dyn.io.IF.joypad = true;
    }
    return fd.inputs.raw;
}

export fn fd_input_release(fd: *base.Fundude, input: u8) u8 {
    _ = fd.inputs.release(&fd.mmu, .{ .raw = input });
    return fd.inputs.raw;
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

export fn fd_screen_ptr(fd: *base.Fundude) *c_void {
    return fd.ppu.screen.data.ptr;
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
