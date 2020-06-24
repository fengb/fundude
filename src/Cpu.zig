const std = @import("std");

const Fundude = @import("main.zig");
pub const Op = @import("Cpu/Op.zig");
const util = @import("util.zig");

const Cpu = @This();

mode: Mode,
interrupt_master: bool,

duration: u8,
remaining: u8,
next: [3]u8,

reg: packed union {
    _16: util.EnumArray(Reg16, u16),
    _8: util.EnumArray(Reg8, u8),
    flags: Flags,
},

pub const Flags = packed struct {
    _pad: u4 = 0,
    C: u1,
    H: u1,
    N: bool,
    Z: bool,
};

test "register arrangement" {
    var cpu: Cpu = undefined;
    cpu.reg._8.set(.A, 0x12);
    cpu.reg._8.set(.F, 0x34);
    std.testing.expectEqual(@as(u16, 0x1234), cpu.reg._16.get(.AF));

    cpu.reg._8.set(.B, 0x23);
    cpu.reg._8.set(.C, 0x34);
    std.testing.expectEqual(@as(u16, 0x2334), cpu.reg._16.get(.BC));

    cpu.reg._8.set(.D, 0x58);
    cpu.reg._8.set(.E, 0x76);
    std.testing.expectEqual(@as(u16, 0x5876), cpu.reg._16.get(.DE));

    cpu.reg._8.set(.H, 0xAF);
    cpu.reg._8.set(.L, 0xCD);
    std.testing.expectEqual(@as(u16, 0xAFCD), cpu.reg._16.get(.HL));
}

test "flags" {
    var cpu: Cpu = undefined;
    cpu.reg.flags = .{
        .Z = true,
        .N = true,
        .H = 1,
        .C = 1,
    };
    std.testing.expectEqual(@as(u8, 0xF0), cpu.reg._8.get(.F));

    cpu.reg.flags = .{
        .Z = true,
        .N = false,
        .H = 0,
        .C = 0,
    };
    std.testing.expectEqual(@as(u8, 0x80), cpu.reg._8.get(.F));

    cpu.reg.flags = .{
        .Z = false,
        .N = false,
        .H = 0,
        .C = 1,
    };
    std.testing.expectEqual(@as(u8, 0x10), cpu.reg._8.get(.F));
}

pub fn reset(self: *Cpu) void {
    self.mode = .norm;
    self.interrupt_master = false;
    self.reg._16.set(.PC, 0);
    self.duration = 0;
    self.remaining = 0;
}

// Always be 4 cycles
pub fn tick(self: *Cpu, mmu: *Fundude.Mmu) void {
    std.debug.assert(self.remaining % 4 == 0);

    if (self.remaining == 0) {
        if (self.irqNext(mmu)) |irqBytes| {
            self.next = irqBytes;

            // TODO: does this really take the same duration as CALL?
            const meta = meta_ops[self.next[0]];
            self.duration = meta.duration;
            self.remaining = meta.duration;
        } else if (self.mode == .halt) {
            return;
        } else {
            self.next = mmu.instrBytes(self.reg._16.get(.PC));

            const meta = meta_ops[self.next[0]];
            self.duration = meta.duration;
            self.remaining = meta.duration;
            self.reg._16.set(.PC, self.reg._16.get(.PC) +% meta.length);
        }
    }

    if (self.remaining == 4) {
        const actual_duration = @call(Fundude.profiling_call, self.opExecute, .{ mmu, self.next });
        // const actual_duration = @call(.{ .modifier = .always_inline }, self.opExecute, .{ mmu, self.next });
        self.remaining = if (actual_duration > self.duration) actual_duration - self.duration else 0;
        self.next = .{ 0, 0, 0 };
    } else {
        self.remaining -%= 4;
    }
}

const meta_ops = blk: {
    @setEvalBranchQuota(10000);
    var result: [256]struct { length: u8, duration: u8 } = undefined;
    for (result) |*val, i| {
        const op = Op.decode(.{ i, 0, 0 });
        val.* = .{ .length = op.length, .duration = op.durations[0] };
    }
    return result;
};

fn irqNext(self: *Cpu, mmu: *Fundude.Mmu) ?[3]u8 {
    if (!self.interrupt_master) return null;

    const cmp = mmu.dyn.io.IF.cmp(mmu.dyn.interrupt_enable);
    const addr: u8 = blk: {
        // Naive implementation:
        // if (cmp.vblank) {
        //     mmu.dyn.io.IF.vblank = false;
        //     break :blk 0x40;
        // } else if (cmp.lcd_stat) {
        //     mmu.dyn.io.IF.lcd_stat = false;
        //     break :blk 0x48;
        // } else if (cmp.timer) {
        //     mmu.dyn.io.IF.timer = false;
        //     break :blk 0x50;
        // } else if (cmp.serial) {
        //     mmu.dyn.io.IF.serial = false;
        //     break :blk 0x58;
        // } else if (cmp.joypad) {
        //     mmu.dyn.io.IF.joypad = false;
        //     break :blk 0x60;
        // } else {
        //     return null;
        // }
        if (cmp.active()) |active| {
            std.debug.assert(cmp.get(active));
            mmu.dyn.io.IF.disable(active);
            break :blk 0x40 + @as(u8, 8) * @enumToInt(active);
        } else {
            return null;
        }
    };

    self.mode = .norm;
    self.interrupt_master = false;

    // return Op.iw___(.call_IW___, addr);
    return [3]u8{ 0xCD, addr, 0 };
}

pub fn opExecute(cpu: *Cpu, mmu: *Fundude.Mmu, bytes: [3]u8) u8 {
    const op = @call(.{ .modifier = .always_inline }, Op.decode, .{bytes});

    inline for (std.meta.fields(Op.Id)) |field| {
        if (field.value == @enumToInt(op.id)) {
            const func = @field(Op.impl, field.name);
            const result = func(cpu, mmu, op);

            const Result = @typeInfo(@TypeOf(func)).Fn.return_type.?;
            std.debug.assert(result.duration == Result.durations[0] or result.duration == Result.durations[1]);

            return @bitCast(u8, result);
        }
    }
    unreachable;
}

test "opExecute smoke" {
    const fd = try std.heap.page_allocator.create(Fundude);
    defer std.heap.page_allocator.destroy(fd);

    fd.mmu.cart_meta.mbc = .None;

    var i: usize = 0;
    while (i < 256) : (i += 1) {
        _ = fd.cpu.opExecute(&fd.mmu, .{ @intCast(u8, i), 0, 0 });
    }

    // CB instructions
    i = 0;
    while (i < 256) : (i += 1) {
        _ = fd.cpu.opExecute(&fd.mmu, .{ 0xCB, @intCast(u8, i), 0 });
    }
}

pub const Mode = enum(u16) {
    norm,
    halt,
    stop,
    illegal,
};

pub const Reg16 = enum(u3) {
    AF = 0,
    BC = 1,
    DE = 2,
    HL = 3,
    SP = 4,
    PC = 5,
};

pub const Reg8 = enum(u3) {
    F = 0,
    A = 1,

    C = 2,
    B = 3,

    E = 4,
    D = 5,

    L = 6,
    H = 7,
};

pub const Irq = packed struct {
    vblank: bool,
    lcd_stat: bool,
    timer: bool,
    serial: bool,
    joypad: bool,
    _pad: u3,

    pub const Pos = enum(u3) {
        vblank,
        lcd_stat,
        timer,
        serial,
        joypad,

        fn mask(self: Pos) u8 {
            return @as(u8, 1) << @enumToInt(self);
        }
    };

    pub fn cmp(self: Irq, other: Irq) Irq {
        return @bitCast(Irq, @bitCast(u8, self) & @bitCast(u8, other));
    }

    pub fn get(self: Irq, pos: Pos) bool {
        return pos.mask() & @bitCast(u8, self) != 0;
    }

    pub fn active(self: Irq) ?Pos {
        const raw = @ctz(u8, @bitCast(u8, self));
        return std.meta.intToEnum(Pos, raw) catch null;
    }

    pub fn disable(self: *Irq, pos: Pos) void {
        self.* = @bitCast(Irq, (~pos.mask()) & @bitCast(u8, self.*));
    }
};

test "" {
    _ = Op;
}
