const base = @import("base.zig");
pub const cb = @import("cpu_opcb.zig").cb;

const Reg8 = base.cpu.Reg8;
const Reg16 = base.cpu.Reg16;
const Flags = base.cpu.Flags;

pub const Result = struct {
    length: u16,
    duration: u8,
    name: []const u8,
    jump: ?u16 = null,
};

pub const Cond = enum(u32) {
    nz,
    z,
    nc,
    c,

    pub fn check(self: Cond, cpu: base.Cpu) bool {
        return switch (self) {
            .nz => !cpu.reg.flags.Z,
            .z => cpu.reg.flags.Z,
            .nc => !cpu.reg.flags.C,
            .c => cpu.reg.flags.C,
        };
    }
};

pub fn ILLEGAL(cpu: *base.Cpu, mmu: *base.Mmu) Result {
    cpu.mode = .illegal;
    return Result{ .length = 1, .duration = 4, .name = "ILLEGAL" };
}

pub fn nop(cpu: *base.Cpu, mmu: *base.Mmu) Result {
    return Result{ .length = 1, .duration = 4, .name = "NOP" };
}

pub fn sys(cpu: *base.Cpu, mmu: *base.Mmu, mode: base.cpu.Mode) Result {
    cpu.mode = mode;
    return Result{ .length = 1, .duration = 4, .name = "MODE" };
}

pub fn scf(cpu: *base.Cpu, mmu: *base.Mmu) Result {
    cpu.reg.flags = Flags{
        .Z = cpu.reg.flags.Z,
        .N = false,
        .H = false,
        .C = true,
    };
    return Result{ .length = 1, .duration = 4, .name = "SCF" };
}

pub fn ccf(cpu: *base.Cpu, mmu: *base.Mmu) Result {
    cpu.reg.flags = Flags{
        .Z = cpu.reg.flags.Z,
        .N = false,
        .H = false,
        .C = !cpu.reg.flags.C,
    };
    return Result{ .length = 1, .duration = 4, .name = "CCF" };
}

pub fn int______(cpu: *base.Cpu, mmu: *base.Mmu, set: bool) Result {
    cpu.interrupt_master = set;
    return Result{ .length = 1, .duration = 4, .name = if (set) "EI" else "DI" };
}

pub fn daa_rr___(cpu: *base.Cpu, mmu: *base.Mmu, dst: Reg8) Result {
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
    return Result{ .length = 1, .duration = 4, .name = "DAA" };
}

pub fn jr__R8___(cpu: *base.Cpu, mmu: *base.Mmu, offset: u8) Result {
    const INST_LENGTH = u8(2);
    return Result{
        .name = "JR",
        .length = INST_LENGTH,
        .duration = 12,
        .jump = signedAdd(cpu.reg._16.get(.PC) + INST_LENGTH, offset),
    };
}

pub fn jr__if_R8(cpu: *base.Cpu, mmu: *base.Mmu, cond: Cond, offset: u8) Result {
    const INST_LENGTH = u8(2);
    return Result{
        .name = "JR",
        .length = INST_LENGTH,
        .duration = 12,
        .jump = if (cond.check(cpu.*)) signedAdd(cpu.reg._16.get(.PC) + INST_LENGTH, offset) else null,
    };
}

pub fn jp__AF___(cpu: *base.Cpu, mmu: *base.Mmu, target: u16) Result {
    return Result{ .name = "JP", .jump = target, .length = 3, .duration = 16 };
}

pub fn jp__if_AF(cpu: *base.Cpu, mmu: *base.Mmu, cond: Cond, target: u16) Result {
    return Result{
        .name = "JP",
        .length = 3,
        .duration = 16,
        .jump = if (cond.check(cpu.*)) target else null,
    };
}

pub fn jp__WW___(cpu: *base.Cpu, mmu: *base.Mmu, target: Reg16) Result {
    return Result{ .name = "JP", .length = 1, .duration = 4, .jump = cpu.reg._16.get(target) };
}

pub fn ret______(cpu: *base.Cpu, mmu: *base.Mmu) Result {
    const target = pop16(cpu, mmu);
    return Result{ .name = "RET", .length = 1, .duration = 16, .jump = target };
}

pub fn rti______(cpu: *base.Cpu, mmu: *base.Mmu) Result {
    const target = pop16(cpu, mmu);
    cpu.interrupt_master = true;
    return Result{ .name = "RETI", .length = 1, .duration = 16, .jump = target };
}

pub fn ret_if___(cpu: *base.Cpu, mmu: *base.Mmu, cond: Cond) Result {
    return Result{
        .name = "RET",
        .length = 1,
        .duration = 8,
        .jump = if (cond.check(cpu.*)) pop16(cpu, mmu) else null,
    };
}

pub fn rst_d8___(cpu: *base.Cpu, mmu: *base.Mmu, target: u8) Result {
    push16(cpu, mmu, cpu.reg._16.get(.PC) + 1);
    return Result{
        .name = "RST",
        .length = 1,
        .duration = 16,
        .jump = target,
    };
}

pub fn cal_AF___(cpu: *base.Cpu, mmu: *base.Mmu, target: u16) Result {
    push16(cpu, mmu, cpu.reg._16.get(.PC) + 3);
    return Result{
        .name = "CALL",
        .length = 3,
        .duration = 24,
        .jump = target,
    };
}

pub fn cal_if_AF(cpu: *base.Cpu, mmu: *base.Mmu, cond: Cond, target: u16) Result {
    return Result{
        .name = "CALL",
        .length = 3,
        .duration = 24,
        .jump = if (!cond.check(cpu.*)) null else blk: {
            push16(cpu, mmu, cpu.reg._16.get(.PC) + 3);
            break :blk target;
        },
    };
}

pub fn rlc_rr___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8) Result {
    cpu.reg._8.set(tgt, doRlc(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return Result{ .name = "RLCA", .length = 1, .duration = 4 };
}

pub fn rla_rr___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8) Result {
    cpu.reg._8.set(tgt, doRl(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return Result{ .name = "RLA", .length = 1, .duration = 4 };
}

pub fn rrc_rr___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8) Result {
    cpu.reg._8.set(tgt, doRrc(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return Result{ .name = "RRC", .length = 1, .duration = 4 };
}

pub fn rra_rr___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8) Result {
    cpu.reg._8.set(tgt, doRr(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return Result{ .name = "RRA", .length = 1, .duration = 4 };
}

pub fn ld__rr_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, d8: u8) Result {
    cpu.reg._8.set(tgt, d8);
    return Result{ .name = "LD", .length = 2, .duration = 8 };
}

pub fn ld__rr_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    cpu.reg._8.copy(tgt, src);
    return Result{ .name = "LD", .length = 1, .duration = 4 };
}

pub fn ld__rr_RR(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    const addr = u16(0xFF00) + cpu.reg._8.get(src);
    cpu.reg._8.set(tgt, mmu.get(addr));
    return Result{ .name = "LD", .length = 1, .duration = 8 };
}

pub fn ld__RR_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    const addr = u16(0xFF00) + cpu.reg._8.get(tgt);
    mmu.set(addr, cpu.reg._8.get(src));
    return Result{ .name = "LD", .length = 1, .duration = 8 };
}

pub fn ld__rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    cpu.reg._8.set(tgt, mmu.get(cpu.reg._16.get(src)));
    return Result{ .name = "LD", .length = 1, .duration = 8 };
}

pub fn ld__ww_df(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16, val: u16) Result {
    cpu.reg._16.set(tgt, val);
    return Result{ .name = "LD", .length = 3, .duration = 12 };
}

pub fn ld__WW_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16, src: Reg8) Result {
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, cpu.reg._8.get(src));
    return Result{ .name = "LD", .length = 1, .duration = 8 };
}

pub fn ld__AF_ww(cpu: *base.Cpu, mmu: *base.Mmu, a16: u16, src: Reg16) Result {
    // TODO: verify this is correct
    mmu.set(a16, mmu.get(cpu.reg._16.get(src)));
    return Result{ .name = "LD", .length = 3, .duration = 20 };
}

pub fn ld__WW_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16, val: u8) Result {
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, val);
    return Result{ .name = "LD", .length = 2, .duration = 12 };
}

pub fn ld__AF_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: u16, src: Reg8) Result {
    mmu.set(tgt, cpu.reg._8.get(src));
    return Result{ .name = "LD", .length = 3, .duration = 16 };
}

pub fn ld__rr_AF(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, val: u16) Result {
    cpu.reg._8.set(tgt, mmu.get(val));
    return Result{ .name = "LD", .length = 3, .duration = 16 };
}

pub fn ld__ww_ww(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16, src: Reg16) Result {
    cpu.reg._16.copy(tgt, src);
    return Result{ .name = "LD", .length = 1, .duration = 8 };
}

pub fn ldh_ww_R8(cpu: *base.Cpu, mmu: *base.Mmu, src: Reg16, offset: u8) Result {
    const val = cpu.reg._16.get(src);
    cpu.reg._16.set(.HL, signedAdd(val, offset));
    return Result{ .name = "LDHL", .length = 2, .duration = 16 };
}

pub fn ldi_WW_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16, src: Reg8) Result {
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, cpu.reg._8.get(src));
    cpu.reg._16.set(tgt, addr +% 1);
    return Result{ .name = "LDI", .length = 1, .duration = 8 };
}

pub fn ldi_rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    cpu.reg._8.set(tgt, mmu.get(addr));
    cpu.reg._16.set(src, addr +% 1);
    return Result{ .name = "LDI", .length = 1, .duration = 8 };
}

pub fn ldd_WW_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16, src: Reg8) Result {
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, cpu.reg._8.get(src));
    cpu.reg._16.set(tgt, addr -% 1);
    return Result{ .name = "LDD", .length = 1, .duration = 8 };
}

pub fn ldd_rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    cpu.reg._8.set(tgt, mmu.get(addr));
    cpu.reg._16.set(src, addr -% 1);
    return Result{ .name = "LDD", .length = 1, .duration = 8 };
}

pub fn ldh_A8_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: u8, src: Reg8) Result {
    mmu.set(u16(0xFF00) + tgt, cpu.reg._8.get(src));
    return Result{ .name = "LDH", .length = 2, .duration = 12 };
}

pub fn ldh_rr_A8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: u8) Result {
    cpu.reg._8.set(tgt, mmu.get(u16(0xFF00) + src));
    return Result{ .name = "LDH", .length = 2, .duration = 12 };
}

pub fn inc_ww___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16) Result {
    const val = cpu.reg._16.get(tgt);
    cpu.reg._16.set(tgt, val +% 1);
    return Result{ .name = "INC", .length = 1, .duration = 8 };
}

pub fn inc_WW___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16) Result {
    const addr = cpu.reg._16.get(tgt);
    const val = mmu.get(addr);
    cpu.reg.flags = Flags{
        .Z = (val +% 1) == 0,
        .N = false,
        .H = willCarryInto(4, val, 1),
        .C = cpu.reg.flags.C,
    };

    mmu.set(addr, val +% 1);
    return Result{ .name = "INC", .length = 1, .duration = 12 };
}

pub fn inc_rr___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8) Result {
    const val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (val +% 1) == 0,
        .N = false,
        .H = willCarryInto(4, val, 1),
        .C = cpu.reg.flags.C,
    };
    cpu.reg._8.set(tgt, val +% 1);
    return Result{ .name = "INC", .length = 1, .duration = 4 };
}

pub fn dec_ww___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16) Result {
    const val = cpu.reg._16.get(tgt);
    cpu.reg._16.set(tgt, val -% 1);
    return Result{ .name = "DEC", .length = 1, .duration = 8 };
}

pub fn dec_WW___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16) Result {
    const addr = cpu.reg._16.get(tgt);
    const val = mmu.get(addr);

    cpu.reg.flags = Flags{
        .Z = (val -% 1) == 0,
        .N = true,
        .H = willBorrowFrom(4, val, 1),
        .C = cpu.reg.flags.C,
    };
    mmu.set(addr, val -% 1);
    return Result{ .name = "DEC", .length = 1, .duration = 12 };
}

pub fn dec_rr___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8) Result {
    const val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (val -% 1) == 0,
        .N = true,
        .H = willBorrowFrom(4, val, 1),
        .C = cpu.reg.flags.C,
    };
    cpu.reg._8.set(tgt, val -% 1);
    return Result{ .name = "DEC", .length = 1, .duration = 4 };
}

pub fn add_rr_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    doAddRr(cpu, tgt, cpu.reg._8.get(src));
    return Result{ .name = "ADD", .length = 1, .duration = 4 };
}

pub fn add_rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    doAddRr(cpu, tgt, mmu.get(addr));
    return Result{ .name = "ADD", .length = 1, .duration = 8 };
}

pub fn add_rr_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, val: u8) Result {
    doAddRr(cpu, tgt, val);
    return Result{ .name = "ADD", .length = 2, .duration = 8 };
}

pub fn add_ww_ww(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16, src: Reg16) Result {
    const src_val = cpu.reg._16.get(src);
    const tgt_val = cpu.reg._16.get(tgt);
    cpu.reg.flags = Flags{
        .Z = cpu.reg.flags.Z,
        .N = false,
        .H = willCarryInto(12, tgt_val, src_val),
        .C = willCarryInto(16, tgt_val, src_val),
    };
    cpu.reg._16.set(tgt, tgt_val +% src_val);
    return Result{ .name = "ADD", .length = 1, .duration = 8 };
}

pub fn add_ww_R8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16, offset: u8) Result {
    const val = cpu.reg._16.get(tgt);
    cpu.reg.flags = Flags{
        .Z = false,
        .N = false,
        .H = willCarryInto(12, val, offset),
        .C = willCarryInto(16, val, offset),
    };
    cpu.reg._16.set(tgt, signedAdd(val, offset));
    return Result{ .name = "ADD", .length = 2, .duration = 16 };
}

pub fn adc_rr_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    doAdcRr(cpu, tgt, cpu.reg._8.get(src));
    return Result{ .name = "ADC", .length = 1, .duration = 4 };
}

pub fn adc_rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    doAdcRr(cpu, tgt, mmu.get(addr));
    return Result{ .name = "ADC", .length = 1, .duration = 8 };
}

pub fn adc_rr_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, val: u8) Result {
    doAdcRr(cpu, tgt, val);
    return Result{ .name = "ADC", .length = 2, .duration = 8 };
}

pub fn sub_rr_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    doSubRr(cpu, tgt, cpu.reg._8.get(src));
    return Result{ .name = "SUB", .length = 1, .duration = 4 };
}

pub fn sub_rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    doSubRr(cpu, tgt, mmu.get(addr));
    return Result{ .name = "SUB", .length = 1, .duration = 8 };
}

pub fn sub_rr_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, val: u8) Result {
    doSubRr(cpu, tgt, val);
    return Result{ .name = "SUB", .length = 2, .duration = 8 };
}

pub fn sbc_rr_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    doSbcRr(cpu, tgt, cpu.reg._8.get(src));
    return Result{ .name = "SBC", .length = 1, .duration = 4 };
}

pub fn sbc_rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    doSbcRr(cpu, tgt, mmu.get(addr));
    return Result{ .name = "SBC", .length = 1, .duration = 8 };
}

pub fn sbc_rr_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, val: u8) Result {
    doSbcRr(cpu, tgt, val);
    return Result{ .name = "SBC", .length = 2, .duration = 8 };
}

pub fn and_rr_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    doAndRr(cpu, tgt, cpu.reg._8.get(src));
    return Result{ .name = "AND", .length = 1, .duration = 4 };
}

pub fn and_rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    doAndRr(cpu, tgt, mmu.get(addr));
    return Result{ .name = "AND", .length = 1, .duration = 8 };
}

pub fn and_rr_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, val: u8) Result {
    doAndRr(cpu, tgt, val);
    return Result{ .name = "AND", .length = 2, .duration = 8 };
}

pub fn or__rr_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    doOrRr(cpu, tgt, cpu.reg._8.get(src));
    return Result{ .name = "OR", .length = 1, .duration = 4 };
}

pub fn or__rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    doOrRr(cpu, tgt, mmu.get(addr));
    return Result{ .name = "OR", .length = 1, .duration = 8 };
}

pub fn or__rr_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, val: u8) Result {
    doOrRr(cpu, tgt, val);
    return Result{ .name = "OR", .length = 2, .duration = 8 };
}

pub fn xor_rr_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    doXorRr(cpu, tgt, cpu.reg._8.get(src));
    return Result{ .name = "XOR", .length = 1, .duration = 4 };
}

pub fn xor_rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    doXorRr(cpu, tgt, mmu.get(addr));
    return Result{ .name = "XOR", .length = 1, .duration = 8 };
}

pub fn xor_rr_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, val: u8) Result {
    doXorRr(cpu, tgt, val);
    return Result{ .name = "XOR", .length = 2, .duration = 8 };
}

pub fn cp__rr_rr(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg8) Result {
    doCpRr(cpu, tgt, cpu.reg._8.get(src));
    return Result{ .name = "CP", .length = 1, .duration = 4 };
}

pub fn cp__rr_WW(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, src: Reg16) Result {
    const addr = cpu.reg._16.get(src);
    doCpRr(cpu, tgt, mmu.get(addr));
    return Result{ .name = "CP", .length = 1, .duration = 8 };
}

pub fn cp__rr_d8(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8, val: u8) Result {
    doCpRr(cpu, tgt, val);
    return Result{ .name = "CP", .length = 2, .duration = 8 };
}

pub fn cpl_rr___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg8) Result {
    const val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = cpu.reg.flags.Z,
        .N = true,
        .H = true,
        .C = cpu.reg.flags.C,
    };
    cpu.reg._8.set(tgt, ~val);
    return Result{ .name = "CPL", .length = 1, .duration = 4 };
}

pub fn psh_ww___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16) Result {
    push16(cpu, mmu, cpu.reg._16.get(tgt));
    return Result{ .name = "PUSH", .length = 1, .duration = 16 };
}

pub fn pop_ww___(cpu: *base.Cpu, mmu: *base.Mmu, tgt: Reg16) Result {
    cpu.reg._16.set(tgt, pop16(cpu, mmu));
    // Always setting is faster than if check
    cpu.reg.flags._pad = 0;
    return Result{ .name = "POP", .length = 1, .duration = 12 };
}

// -- internal

fn willCarryInto(size: u5, a: i32, b: i32) bool {
    if (a < 0 or b < 0) {
        return false;
    }
    const mask = (u32(1) << size) - 1;
    return (@intCast(u32, a) & mask) + (@intCast(u32, b) & mask) > mask;
}

fn willBorrowFrom(size: u5, a: u16, b: u16) bool {
    const mask = (u32(1) << size) - 1;
    return (a & mask) < (b & mask);
}

fn pop8(cpu: *base.Cpu, mmu: *base.Mmu) u8 {
    const addr = cpu.reg._16.get(.SP);
    defer cpu.reg._16.set(.SP, addr +% 1);
    return mmu.get(addr);
}

fn pop16(cpu: *base.Cpu, mmu: *base.Mmu) u16 {
    const lb: u16 = pop8(cpu, mmu);
    const hb: u16 = pop8(cpu, mmu);
    return (hb << 8) | lb;
}

fn push8(cpu: *base.Cpu, mmu: *base.Mmu, val: u8) void {
    const new_addr = cpu.reg._16.get(.SP) -% 1;
    cpu.reg._16.set(.SP, new_addr);
    mmu.set(new_addr, val);
}

fn push16(cpu: *base.Cpu, mmu: *base.Mmu, val: u16) void {
    push8(cpu, mmu, @intCast(u8, val >> 8 & 0xFF));
    push8(cpu, mmu, @intCast(u8, val >> 0 & 0xFF));
}

pub const Bit = struct {
    pub fn get(data: u8, bit: u3) u8 {
        return data >> bit & 1;
    }
};

// TODO: maybe rename? Not too obvious...
pub fn flagShift(cpu: *base.Cpu, val: u8, carry: bool) u8 {
    cpu.reg.flags = Flags{
        .Z = val == 0,
        .N = false,
        .H = false,
        .C = carry,
    };
    return val;
}

pub fn doRlc(cpu: *base.Cpu, val: u8) u8 {
    const msb = Bit.get(val, 7);
    return flagShift(cpu, val << 1 | msb, msb != 0);
}

pub fn doRrc(cpu: *base.Cpu, val: u8) u8 {
    const lsb = Bit.get(val, 0);
    return flagShift(cpu, val >> 1 | (lsb << 7), lsb != 0);
}

pub fn doRl(cpu: *base.Cpu, val: u8) u8 {
    const msb = Bit.get(val, 7);
    return flagShift(cpu, val << 1 | cpu.reg.flags.c(u8), msb != 0);
}

pub fn doRr(cpu: *base.Cpu, val: u8) u8 {
    const lsb = Bit.get(val, 0);
    return flagShift(cpu, val >> 1 | cpu.reg.flags.c(u8) << 7, lsb != 0);
}

fn doAddRr(cpu: *base.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (tgt_val +% val) == 0,
        .N = false,
        .H = willCarryInto(4, tgt_val, val),
        .C = willCarryInto(8, tgt_val, val),
    };
    cpu.reg._8.set(tgt, tgt_val +% val);
}

fn doAdcRr(cpu: *base.Cpu, tgt: Reg8, val: u8) void {
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

fn doSubRr(cpu: *base.Cpu, tgt: Reg8, val: u8) void {
    doCpRr(cpu, tgt, val);
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg._8.set(tgt, tgt_val -% val);
}

fn doSbcRr(cpu: *base.Cpu, tgt: Reg8, val: u8) void {
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

fn doCpRr(cpu: *base.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (tgt_val -% val) == 0,
        .N = true,
        .H = willBorrowFrom(4, tgt_val, val),
        .C = willBorrowFrom(8, tgt_val, val),
    };
}

fn doAndRr(cpu: *base.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg.flags = Flags{
        .Z = (tgt_val & val) == 0,
        .N = false,
        .H = true,
        .C = false,
    };
    cpu.reg._8.set(tgt, tgt_val & val);
}

fn doOrRr(cpu: *base.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg._8.set(tgt, flagShift(cpu, tgt_val | val, false));
}

fn doXorRr(cpu: *base.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg._8.set(tgt, flagShift(cpu, tgt_val ^ val, false));
}

fn signedAdd(a: u16, b: u8) u16 {
    if (b < 128) {
        return a +% b;
    } else {
        return a -% (u16(256) - b);
    }
}
