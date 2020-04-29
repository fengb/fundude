const main = @import("main.zig");
pub const cb = @import("cpu_opcb.zig").cb;

const Reg8 = main.cpu.Reg8;
const Reg16 = main.cpu.Reg16;
const Flags = main.cpu.Flags;

pub const Op = struct {
    microp: Microp,
    len: u8,

    arg0: Arg,
    arg1: Arg,

    cycle0: u8,
    cycle1: u8,

    fn build(microp: Microp, arg0: Arg, arg1: Arg) Op {
        return .{
            .microp = microp,
            .arg0 = arg0,
            .arg1 = arg1,

            .len = undefined,
            .cycle0 = undefined,
            .cycle1 = undefined,
        };
    }

    pub fn _____(microp: Microp) Op {
        return build(microp, .{ .__ = {} }, .{ .__ = {} });
    }

    pub fn tf___(microp: Microp, arg0: bool) Op {
        return build(microp, .{ .tf = arg0 }, .{ .__ = {} });
    }

    pub fn mo___(microp: Microp, arg0: main.cpu.Mode) Op {
        return build(microp, .{ .mo = arg0 }, .{ .__ = {} });
    }

    pub fn ib___(microp: Microp, arg0: u8) Op {
        return build(microp, .{ .ib = arg0 }, .{ .__ = {} });
    }

    pub fn iw___(microp: Microp, arg0: u16) Op {
        return build(microp, .{ .iw = arg0 }, .{ .__ = {} });
    }

    pub fn rb___(microp: Microp, arg0: Reg8) Op {
        return build(microp, .{ .rb = arg0 }, .{ .__ = {} });
    }

    pub fn rw___(microp: Microp, arg0: Reg16) Op {
        return build(microp, .{ .rw = arg0 }, .{ .__ = {} });
    }

    pub fn zc___(microp: Microp, arg0: ZC) Op {
        return build(microp, .{ .zc = arg0 }, .{ .__ = {} });
    }

    pub fn zc_ib(microp: Microp, arg0: ZC, arg1: u8) Op {
        return build(microp, .{ .zc = arg0 }, .{ .ib = arg1 });
    }

    pub fn zc_iw(microp: Microp, arg0: ZC, arg1: u16) Op {
        return build(microp, .{ .zc = arg0 }, .{ .iw = arg1 });
    }

    pub fn ib_rb(microp: Microp, arg0: u8, arg1: Reg8) Op {
        return build(microp, .{ .ib = arg0 }, .{ .rb = arg1 });
    }

    pub fn iw_ib(microp: Microp, arg0: u16, arg1: u8) Op {
        return build(microp, .{ .iw = arg0 }, .{ .ib = arg1 });
    }

    pub fn iw_rb(microp: Microp, arg0: u16, arg1: Reg8) Op {
        return build(microp, .{ .iw = arg0 }, .{ .rb = arg1 });
    }

    pub fn iw_rw(microp: Microp, arg0: u16, arg1: Reg16) Op {
        return build(microp, .{ .iw = arg0 }, .{ .rw = arg1 });
    }

    pub fn rb_ib(microp: Microp, arg0: Reg8, arg1: u8) Op {
        return build(microp, .{ .rb = arg0 }, .{ .ib = arg1 });
    }

    pub fn rb_iw(microp: Microp, arg0: Reg8, arg1: u16) Op {
        return build(microp, .{ .rb = arg0 }, .{ .iw = arg1 });
    }

    pub fn rb_rb(microp: Microp, arg0: Reg8, arg1: Reg8) Op {
        return build(microp, .{ .rb = arg0 }, .{ .rb = arg1 });
    }

    pub fn rb_rw(microp: Microp, arg0: Reg8, arg1: Reg16) Op {
        return build(microp, .{ .rb = arg0 }, .{ .rw = arg1 });
    }

    pub fn rw_ib(microp: Microp, arg0: Reg16, arg1: u8) Op {
        return build(microp, .{ .rw = arg0 }, .{ .ib = arg1 });
    }

    pub fn rw_iw(microp: Microp, arg0: Reg16, arg1: u16) Op {
        return build(microp, .{ .rw = arg0 }, .{ .iw = arg1 });
    }

    pub fn rw_rb(microp: Microp, arg0: Reg16, arg1: Reg8) Op {
        return build(microp, .{ .rw = arg0 }, .{ .rb = arg1 });
    }

    pub fn rw_rw(microp: Microp, arg0: Reg16, arg1: Reg16) Op {
        return build(microp, .{ .rw = arg0 }, .{ .rw = arg1 });
    }
};

const Arg = packed union {
    __: void,
    ib: u8,
    iw: u16,
    rb: Reg8,
    rw: Reg16,

    tf: bool,
    zc: ZC,
    mo: main.cpu.Mode,
};

/// Positional argument types:
/// * rb — register byte
/// * rw — register word
/// * ib — immediate byte
/// * iw — immediate word
/// * RB — register byte address
/// * RW — register word address
/// * IB — immediate byte address
/// * IW — immediate word address
///
/// * tf — true/false
/// * zc — Z/C flag condition
/// * mo — CPU mode
pub const Microp = enum(u8) {
    ILLEGAL,
    nop______,
    int_tf___,
    sys_mo___,

    ccf______,
    scf______,

    jp__IW___,
    jp__RW___,
    jp__zc_IW,
    jr__IB___,
    jr__zc_IB,
    ret______,
    rti______,
    ret_zc___,
    cal_IW___,
    cal_zc_IW,
    rst_ib___,

    ld__IW_rb,
    ld__IW_rw,
    ld__RB_rb,
    ld__RW_ib,
    ld__RW_rb,
    ld__rb_IW,
    ld__rb_RB,
    ld__rb_RW,
    ld__rb_ib,
    ld__rb_rb,
    ld__rw_iw,
    ld__rw_rw,
    ldd_RW_rb,
    ldd_rb_RW,
    ldh_IB_rb,
    ldh_rb_IB,
    ldh_rw_IB,
    ldi_RW_rb,
    ldi_rb_RW,

    add_rb_RW,
    add_rb_ib,
    add_rb_rb,
    add_rw_IB,
    add_rw_rw,
    sub_rb_RW,
    sub_rb_ib,
    sub_rb_rb,
    adc_rb_RW,
    adc_rb_ib,
    adc_rb_rb,
    sbc_rb_RW,
    sbc_rb_ib,
    sbc_rb_rb,

    and_rb_RW,
    and_rb_ib,
    and_rb_rb,
    or__rb_RW,
    or__rb_ib,
    or__rb_rb,
    xor_rb_RW,
    xor_rb_ib,
    xor_rb_rb,
    cp__rb_RW,
    cp__rb_ib,
    cp__rb_rb,

    cpl_rb___,
    daa_rb___,

    dec_RW___,
    dec_rb___,
    dec_rw___,
    inc_RW___,
    inc_rb___,
    inc_rw___,

    pop_rw___,
    psh_rw___,
    rla_rb___,
    rlc_rb___,
    rra_rb___,
    rrc_rb___,

    cb,
};

pub const Result = extern struct {
    duration: u8 = duration,

    fn Fixed(length: u2, duration: u8) type {
        return extern struct {
            const length = length;
            const next_duration = duration;
            const jump_duration = duration;

            duration: u8 = duration,
        };
    }

    fn Cond(length: u2, durations: [2]u8) type {
        return extern struct {
            const length = length;
            const next_duration = durations[0];
            const jump_duration = durations[1];

            duration: u8 = duration,
        };
    }
};

pub const ZC = enum(u32) {
    nz = 0x0_80,
    z = 0x80_80,
    nc = 0x0_10,
    c = 0x10_10,

    pub fn check(self: ZC, cpu: main.Cpu) bool {
        // return switch (self) {
        //     .nz => !cpu.reg.flags.Z,
        //     .z => cpu.reg.flags.Z,
        //     .nc => !cpu.reg.flags.C,
        //     .c => cpu.reg.flags.C,
        // };
        const compare = @enumToInt(self) >> 8;
        const mask = 0xff & @enumToInt(self);
        return mask & @bitCast(u8, cpu.reg.flags) == compare;
    }
};

pub fn ILLEGAL(cpu: *main.Cpu, mmu: *main.Mmu) Result.Fixed(1, 4) {
    cpu.mode = .illegal;
    return .{};
}

pub fn nop(cpu: *main.Cpu, mmu: *main.Mmu) Result.Fixed(1, 4) {
    return .{};
}

pub fn sys(cpu: *main.Cpu, mmu: *main.Mmu, mode: main.cpu.Mode) Result.Fixed(1, 4) {
    return .{};
}

pub fn scf(cpu: *main.Cpu, mmu: *main.Mmu) Result.Fixed(1, 4) {
    cpu.reg.flags = Flags{
        .Z = cpu.reg.flags.Z,
        .N = false,
        .H = false,
        .C = true,
    };
    return .{};
}

pub fn ccf(cpu: *main.Cpu, mmu: *main.Mmu) Result.Fixed(1, 4) {
    cpu.reg.flags = Flags{
        .Z = cpu.reg.flags.Z,
        .N = false,
        .H = false,
        .C = !cpu.reg.flags.C,
    };
    return .{};
}

pub fn int______(cpu: *main.Cpu, mmu: *main.Mmu, set: bool) Result.Fixed(1, 4) {
    cpu.interrupt_master = set;
    return .{};
}

pub fn daa_rb___(cpu: *main.Cpu, mmu: *main.Mmu, dst: Reg8) Result.Fixed(1, 4) {
    // https://www.reddit.com/r/EmuDev/comments/4ycoix/a_guide_to_the_gameboys_halfcarry_flag/d6p3rtl?utm_source=share&utm_medium=web2x
    // On the Z80:
    // If C is set OR a > 0x99, add or subtract 0x60 depending on N, and set C
    // If H is set OR (a & 0xf) > 9, add or subtract 6 depending on N

    // On the GB:
    // DAA after an add (N flag clear) works the same way as on the Z80
    // DAA after a subtract (N flag set) only tests the C and H flags, and not the previous value of a
    // H is always cleared (for both add and subtract)
    // N is preserved, Z is set the usual way, and the rest of the Z80 flags don't exist
    const start = cpu.reg._8.get(dst);
    var val = start;
    var carry = cpu.reg.flags.C;

    if (cpu.reg.flags.N) {
        // SUB -> DAA
        if (cpu.reg.flags.H) {
            val -%= 0x6;
        }

        if (cpu.reg.flags.C) {
            val -%= 0x60;
        }

        if (val > start) {
            carry = true;
        }
    } else {
        // ADD -> DAA
        if (cpu.reg.flags.H or (start >> 0 & 0xF) > 0x9) {
            val +%= 0x6;
        }

        if (cpu.reg.flags.C or (start >> 4 & 0xF) > 0x9) {
            val +%= 0x60;
        }

        if (val < start) {
            carry = true;
        }
    }

    cpu.reg._8.set(dst, val);
    cpu.reg.flags = Flags{
        .Z = val == 0,
        .N = cpu.reg.flags.N,
        .H = false,
        .C = carry,
    };
    return .{};
}

pub fn jr__IB___(cpu: *main.Cpu, mmu: *main.Mmu, offset: u8) Result.Fixed(2, 12) {
    const jump = signedAdd(cpu.reg._16.get(.PC), offset);
    cpu.reg._16.set(.PC, jump);
    return .{};
}

pub fn jr__zc_IB(cpu: *main.Cpu, mmu: *main.Mmu, cond: ZC, offset: u8) Result.Cond(2, .{ 8, 12 }) {
    if (cond.check(cpu.*)) {
        const jump = signedAdd(cpu.reg._16.get(.PC), offset);
        cpu.reg._16.set(.PC, jump);
        return .{ .duration = 12 };
    }
    return .{ .duration = 8 };
}

pub fn jp__IW___(cpu: *main.Cpu, mmu: *main.Mmu, target: u16) Result.Fixed(3, 16) {
    cpu.reg._16.set(.PC, target);
    return .{};
}

pub fn jp__zc_IW(cpu: *main.Cpu, mmu: *main.Mmu, cond: ZC, target: u16) Result.Cond(3, .{ 16, 12 }) {
    if (cond.check(cpu.*)) {
        cpu.reg._16.set(.PC, target);
        return .{ .duration = 16 };
    }
    return .{ .duration = 12 };
}

pub fn jp__RW___(cpu: *main.Cpu, mmu: *main.Mmu, target: Reg16) Result.Fixed(1, 4) {
    const jump = cpu.reg._16.get(target);
    cpu.reg._16.set(.PC, jump);
    return .{};
}

pub fn ret______(cpu: *main.Cpu, mmu: *main.Mmu) Result.Fixed(1, 16) {
    const jump = pop16(cpu, mmu);
    cpu.reg._16.set(.PC, jump);
    return .{};
}

pub fn rti______(cpu: *main.Cpu, mmu: *main.Mmu) Result.Fixed(1, 16) {
    const jump = pop16(cpu, mmu);
    cpu.reg._16.set(.PC, jump);
    cpu.interrupt_master = true;
    return .{};
}

pub fn ret_zc___(cpu: *main.Cpu, mmu: *main.Mmu, cond: ZC) Result.Cond(1, .{ 8, 20 }) {
    if (cond.check(cpu.*)) {
        const jump = pop16(cpu, mmu);
        cpu.reg._16.set(.PC, jump);
        return .{ .duration = 20 };
    }
    return .{ .duration = 8 };
}

pub fn rst_ib___(cpu: *main.Cpu, mmu: *main.Mmu, target: u8) Result.Fixed(1, 16) {
    push16(cpu, mmu, cpu.reg._16.get(.PC));
    cpu.reg._16.set(.PC, target);
    return .{};
}

pub fn cal_IW___(cpu: *main.Cpu, mmu: *main.Mmu, target: u16) Result.Fixed(3, 24) {
    push16(cpu, mmu, cpu.reg._16.get(.PC));
    cpu.reg._16.set(.PC, target);
    return .{};
}

pub fn cal_zc_IW(cpu: *main.Cpu, mmu: *main.Mmu, cond: ZC, target: u16) Result.Cond(3, .{ 12, 24 }) {
    if (cond.check(cpu.*)) {
        push16(cpu, mmu, cpu.reg._16.get(.PC));
        cpu.reg._16.set(.PC, target);
        return .{};
    }
    return .{};
}

pub fn rlc_rb___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8) Result.Fixed(1, 4) {
    cpu.reg._8.set(tgt, doRlc(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return .{};
}

pub fn rla_rb___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8) Result.Fixed(1, 4) {
    cpu.reg._8.set(tgt, doRl(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return .{};
}

pub fn rrc_rb___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8) Result.Fixed(1, 4) {
    cpu.reg._8.set(tgt, doRrc(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return .{};
}

pub fn rra_rb___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8) Result.Fixed(1, 4) {
    cpu.reg._8.set(tgt, doRr(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return .{};
}

pub fn ld__rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, d8: u8) Result.Fixed(2, 8) {
    cpu.reg._8.set(tgt, d8);
    return .{};
}

pub fn ld__rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 4) {
    cpu.reg._8.copy(tgt, src);
    return .{};
}

pub fn ld__rb_RB(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 8) {
    const addr = @as(u16, 0xFF00) + cpu.reg._8.get(src);
    cpu.reg._8.set(tgt, mmu.get(addr));
    return .{};
}

pub fn ld__RB_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 8) {
    const addr = @as(u16, 0xFF00) + cpu.reg._8.get(tgt);
    mmu.set(addr, cpu.reg._8.get(src));
    return .{};
}

pub fn ld__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    cpu.reg._8.set(tgt, mmu.get(cpu.reg._16.get(src)));
    return .{};
}

pub fn ld__rw_iw(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16, val: u16) Result.Fixed(3, 12) {
    cpu.reg._16.set(tgt, val);
    return .{};
}

pub fn ld__RW_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16, src: Reg8) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, cpu.reg._8.get(src));
    return .{};
}

pub fn ld__IW_rw(cpu: *main.Cpu, mmu: *main.Mmu, a16: u16, src: Reg16) Result.Fixed(3, 20) {
    // TODO: verify this is correct
    mmu.set(a16, mmu.get(cpu.reg._16.get(src)));
    return .{};
}

pub fn ld__RW_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16, val: u8) Result.Fixed(2, 12) {
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, val);
    return .{};
}

pub fn ld__IW_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: u16, src: Reg8) Result.Fixed(3, 16) {
    mmu.set(tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn ld__rb_IW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, val: u16) Result.Fixed(3, 16) {
    cpu.reg._8.set(tgt, mmu.get(val));
    return .{};
}

pub fn ld__rw_rw(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16, src: Reg16) Result.Fixed(1, 8) {
    cpu.reg._16.copy(tgt, src);
    return .{};
}

pub fn ldh_rw_IB(cpu: *main.Cpu, mmu: *main.Mmu, src: Reg16, offset: u8) Result.Fixed(2, 16) {
    const val = cpu.reg._16.get(src);
    cpu.reg._16.set(.HL, signedAdd(val, offset));
    return .{};
}

pub fn ldi_RW_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16, src: Reg8) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, cpu.reg._8.get(src));
    cpu.reg._16.set(tgt, addr +% 1);
    return .{};
}

pub fn ldi_rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    cpu.reg._8.set(tgt, mmu.get(addr));
    cpu.reg._16.set(src, addr +% 1);
    return .{};
}

pub fn ldd_RW_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16, src: Reg8) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, cpu.reg._8.get(src));
    cpu.reg._16.set(tgt, addr -% 1);
    return .{};
}

pub fn ldd_rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    cpu.reg._8.set(tgt, mmu.get(addr));
    cpu.reg._16.set(src, addr -% 1);
    return .{};
}

pub fn ldh_IB_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: u8, src: Reg8) Result.Fixed(2, 12) {
    mmu.set(@as(u16, 0xFF00) + tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn ldh_rb_IB(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: u8) Result.Fixed(2, 12) {
    cpu.reg._8.set(tgt, mmu.get(@as(u16, 0xFF00) + src));
    return .{};
}

pub fn inc_rw___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16) Result.Fixed(1, 8) {
    const val = cpu.reg._16.get(tgt);
    cpu.reg._16.set(tgt, val +% 1);
    return .{};
}

pub fn inc_RW___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16) Result.Fixed(1, 12) {
    const addr = cpu.reg._16.get(tgt);
    const val = mmu.get(addr);
    cpu.reg.flags = Flags{
        .Z = (val +% 1) == 0,
        .N = false,
        .H = willCarryInto(4, val, 1),
        .C = cpu.reg.flags.C,
    };

    mmu.set(addr, val +% 1);
    return .{};
}

pub fn inc_rb___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8) Result.Fixed(1, 4) {
    const val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (val +% 1) == 0,
        .N = false,
        .H = willCarryInto(4, val, 1),
        .C = cpu.reg.flags.C,
    };
    cpu.reg._8.set(tgt, val +% 1);
    return .{};
}

pub fn dec_rw___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16) Result.Fixed(1, 8) {
    const val = cpu.reg._16.get(tgt);
    cpu.reg._16.set(tgt, val -% 1);
    return .{};
}

pub fn dec_RW___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16) Result.Fixed(1, 12) {
    const addr = cpu.reg._16.get(tgt);
    const val = mmu.get(addr);

    cpu.reg.flags = Flags{
        .Z = (val -% 1) == 0,
        .N = true,
        .H = willBorrowFrom(4, val, 1),
        .C = cpu.reg.flags.C,
    };
    mmu.set(addr, val -% 1);
    return .{};
}

pub fn dec_rb___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8) Result.Fixed(1, 4) {
    const val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (val -% 1) == 0,
        .N = true,
        .H = willBorrowFrom(4, val, 1),
        .C = cpu.reg.flags.C,
    };
    cpu.reg._8.set(tgt, val -% 1);
    return .{};
}

pub fn add_rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 4) {
    doAddRr(cpu, tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn add_rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    doAddRr(cpu, tgt, mmu.get(addr));
    return .{};
}

pub fn add_rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, val: u8) Result.Fixed(2, 8) {
    doAddRr(cpu, tgt, val);
    return .{};
}

pub fn add_rw_rw(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16, src: Reg16) Result.Fixed(1, 8) {
    const src_val = cpu.reg._16.get(src);
    const tgt_val = cpu.reg._16.get(tgt);
    cpu.reg.flags = Flags{
        .Z = cpu.reg.flags.Z,
        .N = false,
        .H = willCarryInto(12, tgt_val, src_val),
        .C = willCarryInto(16, tgt_val, src_val),
    };
    cpu.reg._16.set(tgt, tgt_val +% src_val);
    return .{};
}

pub fn add_rw_IB(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16, offset: u8) Result.Fixed(2, 16) {
    const val = cpu.reg._16.get(tgt);
    cpu.reg.flags = Flags{
        .Z = false,
        .N = false,
        .H = willCarryInto(12, val, offset),
        .C = willCarryInto(16, val, offset),
    };
    cpu.reg._16.set(tgt, signedAdd(val, offset));
    return .{};
}

pub fn adc_rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 4) {
    doAdcRr(cpu, tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn adc_rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    doAdcRr(cpu, tgt, mmu.get(addr));
    return .{};
}

pub fn adc_rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, val: u8) Result.Fixed(2, 8) {
    doAdcRr(cpu, tgt, val);
    return .{};
}

pub fn sub_rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 4) {
    doSubRr(cpu, tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn sub_rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    doSubRr(cpu, tgt, mmu.get(addr));
    return .{};
}

pub fn sub_rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, val: u8) Result.Fixed(2, 8) {
    doSubRr(cpu, tgt, val);
    return .{};
}

pub fn sbc_rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 4) {
    doSbcRr(cpu, tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn sbc_rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    doSbcRr(cpu, tgt, mmu.get(addr));
    return .{};
}

pub fn sbc_rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, val: u8) Result.Fixed(2, 8) {
    doSbcRr(cpu, tgt, val);
    return .{};
}

pub fn and_rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 4) {
    doAndRr(cpu, tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn and_rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    doAndRr(cpu, tgt, mmu.get(addr));
    return .{};
}

pub fn and_rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, val: u8) Result.Fixed(2, 8) {
    doAndRr(cpu, tgt, val);
    return .{};
}

pub fn or__rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 4) {
    doOrRr(cpu, tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn or__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    doOrRr(cpu, tgt, mmu.get(addr));
    return .{};
}

pub fn or__rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, val: u8) Result.Fixed(2, 8) {
    doOrRr(cpu, tgt, val);
    return .{};
}

pub fn xor_rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 4) {
    doXorRr(cpu, tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn xor_rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    doXorRr(cpu, tgt, mmu.get(addr));
    return .{};
}

pub fn xor_rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, val: u8) Result.Fixed(2, 8) {
    doXorRr(cpu, tgt, val);
    return .{};
}

pub fn cp__rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg8) Result.Fixed(1, 4) {
    doCpRr(cpu, tgt, cpu.reg._8.get(src));
    return .{};
}

pub fn cp__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, src: Reg16) Result.Fixed(1, 8) {
    const addr = cpu.reg._16.get(src);
    doCpRr(cpu, tgt, mmu.get(addr));
    return .{};
}

pub fn cp__rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8, val: u8) Result.Fixed(2, 8) {
    doCpRr(cpu, tgt, val);
    return .{};
}

pub fn cpl_rb___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg8) Result.Fixed(1, 4) {
    const val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = cpu.reg.flags.Z,
        .N = true,
        .H = true,
        .C = cpu.reg.flags.C,
    };
    cpu.reg._8.set(tgt, ~val);
    return .{};
}

pub fn psh_rw___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16) Result.Fixed(1, 16) {
    push16(cpu, mmu, cpu.reg._16.get(tgt));
    return .{};
}

pub fn pop_rw___(cpu: *main.Cpu, mmu: *main.Mmu, tgt: Reg16) Result.Fixed(1, 12) {
    cpu.reg._16.set(tgt, pop16(cpu, mmu));
    // Always setting is faster than if check
    cpu.reg.flags._pad = 0;
    return .{};
}

// -- internal

fn willCarryInto(size: u5, a: i32, b: i32) bool {
    if (a < 0 or b < 0) {
        return false;
    }
    const mask = (@as(u32, 1) << size) - 1;
    return (@intCast(u32, a) & mask) + (@intCast(u32, b) & mask) > mask;
}

fn willBorrowFrom(size: u5, a: u16, b: u16) bool {
    const mask = (@as(u32, 1) << size) - 1;
    return (a & mask) < (b & mask);
}

fn pop8(cpu: *main.Cpu, mmu: *main.Mmu) u8 {
    const addr = cpu.reg._16.get(.SP);
    defer cpu.reg._16.set(.SP, addr +% 1);
    return mmu.get(addr);
}

fn pop16(cpu: *main.Cpu, mmu: *main.Mmu) u16 {
    const lb: u16 = pop8(cpu, mmu);
    const hb: u16 = pop8(cpu, mmu);
    return (hb << 8) | lb;
}

fn push8(cpu: *main.Cpu, mmu: *main.Mmu, val: u8) void {
    const new_addr = cpu.reg._16.get(.SP) -% 1;
    cpu.reg._16.set(.SP, new_addr);
    mmu.set(new_addr, val);
}

fn push16(cpu: *main.Cpu, mmu: *main.Mmu, val: u16) void {
    push8(cpu, mmu, @intCast(u8, val >> 8 & 0xFF));
    push8(cpu, mmu, @intCast(u8, val >> 0 & 0xFF));
}

pub const Bit = struct {
    pub fn get(data: u8, bit: u3) u8 {
        return data >> bit & 1;
    }
};

// TODO: maybe rename? Not too obvious...
pub fn flagShift(cpu: *main.Cpu, val: u8, carry: bool) u8 {
    cpu.reg.flags = Flags{
        .Z = val == 0,
        .N = false,
        .H = false,
        .C = carry,
    };
    return val;
}

pub fn doRlc(cpu: *main.Cpu, val: u8) u8 {
    const msb = Bit.get(val, 7);
    return flagShift(cpu, val << 1 | msb, msb != 0);
}

pub fn doRrc(cpu: *main.Cpu, val: u8) u8 {
    const lsb = Bit.get(val, 0);
    return flagShift(cpu, val >> 1 | (lsb << 7), lsb != 0);
}

pub fn doRl(cpu: *main.Cpu, val: u8) u8 {
    const msb = Bit.get(val, 7);
    return flagShift(cpu, val << 1 | cpu.reg.flags.c(u8), msb != 0);
}

pub fn doRr(cpu: *main.Cpu, val: u8) u8 {
    const lsb = Bit.get(val, 0);
    return flagShift(cpu, val >> 1 | cpu.reg.flags.c(u8) << 7, lsb != 0);
}

fn doAddRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (tgt_val +% val) == 0,
        .N = false,
        .H = willCarryInto(4, tgt_val, val),
        .C = willCarryInto(8, tgt_val, val),
    };
    cpu.reg._8.set(tgt, tgt_val +% val);
}

fn doAdcRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    const carry = cpu.reg.flags.c(u1);
    cpu.reg.flags = Flags{
        .Z = (tgt_val +% val +% carry) == 0,
        .N = false,
        .H = willCarryInto(4, tgt_val, val) or willCarryInto(4, tgt_val, val +% carry),
        .C = willCarryInto(8, tgt_val, val) or willCarryInto(8, tgt_val, val +% carry),
    };
    cpu.reg._8.set(tgt, tgt_val +% val +% carry);
}

fn doSubRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    doCpRr(cpu, tgt, val);
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg._8.set(tgt, tgt_val -% val);
}

fn doSbcRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    const carry = cpu.reg.flags.c(u1);
    cpu.reg.flags = Flags{
        .Z = (tgt_val -% val -% carry) == 0,
        .N = true,
        .H = willBorrowFrom(4, tgt_val, val) or willBorrowFrom(4, tgt_val -% val, carry),
        .C = willBorrowFrom(8, tgt_val, val) or willBorrowFrom(8, tgt_val -% val, carry),
    };
    cpu.reg._8.set(tgt, tgt_val -% val -% carry);
}

fn doCpRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (tgt_val -% val) == 0,
        .N = true,
        .H = willBorrowFrom(4, tgt_val, val),
        .C = willBorrowFrom(8, tgt_val, val),
    };
}

fn doAndRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (tgt_val & val) == 0,
        .N = false,
        .H = true,
        .C = false,
    };
    cpu.reg._8.set(tgt, tgt_val & val);
}

fn doOrRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg._8.set(tgt, flagShift(cpu, tgt_val | val, false));
}

fn doXorRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg._8.set(tgt, flagShift(cpu, tgt_val ^ val, false));
}

fn signedAdd(a: u16, b: u8) u16 {
    const signed = @bitCast(i16, a) +% @bitCast(i8, b);
    return @bitCast(u16, signed);
}
