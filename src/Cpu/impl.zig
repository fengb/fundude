const main = @import("../main.zig");
const Op = @import("Op.zig");
pub const cb___ib___ = @import("cpu_opcb.zig").cb___ib___;

const Reg8 = main.Cpu.Reg8;
const Reg16 = main.Cpu.Reg16;

pub fn Result(lengt: u2, duration: var) type {
    if (duration.len == 1) {
        return extern struct {
            pub const length = lengt;
            pub const durations = [_]u8{duration[0]} ** 2;

            duration: u8 = duration[0],
        };
    } else {
        return extern struct {
            pub const length = lengt;
            // Switch to this once "type coercion of anon list literal to array"
            // pub const durations: [2]u8 = duration;
            pub const durations = [_]u8{ duration[0], duration[1] };

            duration: u8,
        };
    }
}

pub fn ILLEGAL___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    cpu.mode = .illegal;
    return .{};
}

pub fn nop_______(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    return .{};
}

pub fn sys__mo___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    cpu.mode = op.arg0.mo;
    return .{};
}

pub fn scf_______(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    cpu.reg.flags = .{
        .Z = cpu.reg.flags.Z,
        .N = false,
        .H = 0,
        .C = 1,
    };
    return .{};
}

pub fn ccf_______(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    cpu.reg.flags = .{
        .Z = cpu.reg.flags.Z,
        .N = false,
        .H = 0,
        .C = ~cpu.reg.flags.C,
    };
    return .{};
}

pub fn int__tf___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    cpu.interrupt_master = op.arg0.tf;
    return .{};
}

pub fn daa__rb___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    // https://www.reddit.com/r/EmuDev/comments/4ycoix/a_guide_to_the_gameboys_halfcarry_flag/d6p3rtl?utm_source=share&utm_medium=web2x
    // On the Z80:
    // If C is set OR a > 0x99, add or subtract 0x60 depending on N, and set C
    // If H is set OR (a & 0xf) > 9, add or subtract 6 depending on N

    // On the GB:
    // DAA after an add (N flag clear) works the same way as on the Z80
    // DAA after a subtract (N flag set) only tests the C and H flags, and not the previous value of a
    // H is always cleared (for both add and subtract)
    // N is preserved, Z is set the usual way, and the rest of the Z80 flags don't exist
    const dst = op.arg0.rb;

    const start = cpu.reg._8.get(dst);
    var val = start;
    var carry = cpu.reg.flags.C;

    if (cpu.reg.flags.N) {
        // SUB -> DAA
        if (cpu.reg.flags.H == 1) {
            val -%= 0x6;
        }

        if (cpu.reg.flags.C == 1) {
            val -%= 0x60;
        }

        if (val > start) {
            carry = 1;
        }
    } else {
        // ADD -> DAA
        if (cpu.reg.flags.H == 1 or (start >> 0 & 0xF) > 0x9) {
            val +%= 0x6;
        }

        if (cpu.reg.flags.C == 1 or (start >> 4 & 0xF) > 0x9) {
            val +%= 0x60;
        }

        if (val < start) {
            carry = 1;
        }
    }

    cpu.reg._8.set(dst, val);
    cpu.reg.flags = .{
        .Z = val == 0,
        .N = cpu.reg.flags.N,
        .H = 0,
        .C = carry,
    };
    return .{};
}

pub fn jr___IB___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{12}) {
    const jump = signedAdd(cpu.reg._16.get(.PC), op.arg0.ib);
    cpu.reg._16.set(.PC, jump);
    return .{};
}

pub fn jr___zc_IB(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{ 8, 12 }) {
    if (op.arg0.zc.check(cpu.*)) {
        const jump = signedAdd(cpu.reg._16.get(.PC), op.arg1.ib);
        cpu.reg._16.set(.PC, jump);
        return .{ .duration = 12 };
    }
    return .{ .duration = 8 };
}

pub fn jp___IW___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(3, .{16}) {
    cpu.reg._16.set(.PC, op.arg0.iw);
    return .{};
}

pub fn jp___zc_IW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(3, .{ 12, 16 }) {
    if (op.arg0.zc.check(cpu.*)) {
        cpu.reg._16.set(.PC, op.arg1.iw);
        return .{ .duration = 16 };
    }
    return .{ .duration = 12 };
}

pub fn jp___RW___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    const jump = cpu.reg._16.get(op.arg0.rw);
    cpu.reg._16.set(.PC, jump);
    return .{};
}

pub fn ret_______(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{16}) {
    const jump = pop16(cpu, mmu);
    cpu.reg._16.set(.PC, jump);
    return .{};
}

pub fn reti______(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{16}) {
    const jump = pop16(cpu, mmu);
    cpu.reg._16.set(.PC, jump);
    cpu.interrupt_master = true;
    return .{};
}

pub fn ret__zc___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{ 8, 20 }) {
    if (op.arg0.zc.check(cpu.*)) {
        const jump = pop16(cpu, mmu);
        cpu.reg._16.set(.PC, jump);
        return .{ .duration = 20 };
    }
    return .{ .duration = 8 };
}

pub fn rst__ib___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{16}) {
    push16(cpu, mmu, cpu.reg._16.get(.PC));
    cpu.reg._16.set(.PC, op.arg0.ib);
    return .{};
}

pub fn call_IW___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(3, .{24}) {
    push16(cpu, mmu, cpu.reg._16.get(.PC));
    cpu.reg._16.set(.PC, op.arg0.iw);
    return .{};
}

pub fn call_zc_IW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(3, .{ 12, 24 }) {
    if (op.arg0.zc.check(cpu.*)) {
        push16(cpu, mmu, cpu.reg._16.get(.PC));
        cpu.reg._16.set(.PC, op.arg1.iw);
        return .{ .duration = 24 };
    }
    return .{ .duration = 12 };
}

pub fn rlca_rb___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    const tgt = op.arg0.rb;
    cpu.reg._8.set(tgt, doRlc(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return .{};
}

pub fn rla__rb___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    const tgt = op.arg0.rb;
    cpu.reg._8.set(tgt, doRl(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return .{};
}

pub fn rrca_rb___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    const tgt = op.arg0.rb;
    cpu.reg._8.set(tgt, doRrc(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return .{};
}

pub fn rra__rb___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    const tgt = op.arg0.rb;
    cpu.reg._8.set(tgt, doRr(cpu, cpu.reg._8.get(tgt)));
    cpu.reg.flags.Z = false;
    return .{};
}

pub fn ld___rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{8}) {
    cpu.reg._8.set(op.arg0.rb, op.arg1.ib);
    return .{};
}

pub fn ld___rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    cpu.reg._8.copy(op.arg0.rb, op.arg1.rb);
    return .{};
}

pub fn ld___rb_RB(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = @as(u16, 0xFF00) + cpu.reg._8.get(op.arg1.rb);
    cpu.reg._8.set(op.arg0.rb, mmu.get(addr));
    return .{};
}

pub fn ld___RB_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = @as(u16, 0xFF00) + cpu.reg._8.get(op.arg0.rb);
    mmu.set(addr, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn ld___rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    cpu.reg._8.set(op.arg0.rb, mmu.get(cpu.reg._16.get(op.arg1.rw)));
    return .{};
}

pub fn ld___rw_iw(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(3, .{12}) {
    cpu.reg._16.set(op.arg0.rw, op.arg1.iw);
    return .{};
}

pub fn ld___RW_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = cpu.reg._16.get(op.arg0.rw);
    mmu.set(addr, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn ld___IW_rw(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(3, .{20}) {
    // TODO: verify this is correct
    const val = cpu.reg._16.get(op.arg1.rw);
    mmu.set(op.arg0.iw, @truncate(u8, val));
    mmu.set(op.arg0.iw +% 1, @truncate(u8, val >> 8));
    return .{};
}

pub fn ld___RW_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{12}) {
    const addr = cpu.reg._16.get(op.arg0.rw);
    mmu.set(addr, op.arg1.ib);
    return .{};
}

pub fn ld___IW_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(3, .{16}) {
    mmu.set(op.arg0.iw, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn ld___rb_IW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(3, .{16}) {
    cpu.reg._8.set(op.arg0.rb, mmu.get(op.arg1.iw));
    return .{};
}

pub fn ld___rw_rw(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    cpu.reg._16.copy(op.arg0.rw, op.arg1.rw);
    return .{};
}

pub fn ldhl_rw_IB(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{16}) {
    // TODO: audit LDHL SP,n
    const val = cpu.reg._16.get(op.arg0.rw);
    cpu.reg._16.set(.HL, signedAdd(val, op.arg1.ib));
    return .{};
}

pub fn ldi__RW_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const tgt = op.arg0.rw;
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, cpu.reg._8.get(op.arg1.rb));
    cpu.reg._16.set(tgt, addr +% 1);
    return .{};
}

pub fn ldi__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const src = op.arg1.rw;
    const addr = cpu.reg._16.get(src);
    cpu.reg._8.set(op.arg0.rb, mmu.get(addr));
    cpu.reg._16.set(src, addr +% 1);
    return .{};
}

pub fn ldd__RW_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const tgt = op.arg0.rw;
    const addr = cpu.reg._16.get(tgt);
    mmu.set(addr, cpu.reg._8.get(op.arg1.rb));
    cpu.reg._16.set(tgt, addr -% 1);
    return .{};
}

pub fn ldd__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const src = op.arg1.rw;
    const addr = cpu.reg._16.get(src);
    cpu.reg._8.set(op.arg0.rb, mmu.get(addr));
    cpu.reg._16.set(src, addr -% 1);
    return .{};
}

pub fn ldh__IB_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{12}) {
    mmu.set(@as(u16, 0xFF00) + op.arg0.ib, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn ldh__rb_IB(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{12}) {
    cpu.reg._8.set(op.arg0.rb, mmu.get(@as(u16, 0xFF00) + op.arg1.ib));
    return .{};
}

pub fn inc__rw___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const val = cpu.reg._16.get(op.arg0.rw);
    cpu.reg._16.set(op.arg0.rw, val +% 1);
    return .{};
}

pub fn inc__RW___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{12}) {
    const addr = cpu.reg._16.get(op.arg0.rw);
    const val = mmu.get(addr);
    cpu.reg.flags = .{
        .Z = (val +% 1) == 0,
        .N = false,
        .H = willCarryInto(4, val, 1),
        .C = cpu.reg.flags.C,
    };

    mmu.set(addr, val +% 1);
    return .{};
}

pub fn inc__rb___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    const val = cpu.reg._8.get(op.arg0.rb);
    cpu.reg.flags = .{
        .Z = (val +% 1) == 0,
        .N = false,
        .H = willCarryInto(4, val, 1),
        .C = cpu.reg.flags.C,
    };
    cpu.reg._8.set(op.arg0.rb, val +% 1);
    return .{};
}

pub fn dec__rw___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const val = cpu.reg._16.get(op.arg0.rw);
    cpu.reg._16.set(op.arg0.rw, val -% 1);
    return .{};
}

pub fn dec__RW___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{12}) {
    const addr = cpu.reg._16.get(op.arg0.rw);
    const val = mmu.get(addr);

    cpu.reg.flags = .{
        .Z = (val -% 1) == 0,
        .N = true,
        .H = willBorrowFrom(4, val, 1),
        .C = cpu.reg.flags.C,
    };
    mmu.set(addr, val -% 1);
    return .{};
}

pub fn dec__rb___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    const val = cpu.reg._8.get(op.arg0.rb);
    cpu.reg.flags = .{
        .Z = (val -% 1) == 0,
        .N = true,
        .H = willBorrowFrom(4, val, 1),
        .C = cpu.reg.flags.C,
    };
    cpu.reg._8.set(op.arg0.rb, val -% 1);
    return .{};
}

pub fn add__rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    doAddRr(cpu, op.arg0.rb, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn add__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = cpu.reg._16.get(op.arg1.rw);
    doAddRr(cpu, op.arg0.rb, mmu.get(addr));
    return .{};
}

pub fn add__rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{8}) {
    doAddRr(cpu, op.arg0.rb, op.arg1.ib);
    return .{};
}

pub fn add__rw_rw(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const tgt = op.arg0.rw;
    const src_val = cpu.reg._16.get(op.arg1.rw);
    const tgt_val = cpu.reg._16.get(tgt);
    cpu.reg.flags = .{
        .Z = cpu.reg.flags.Z,
        .N = false,
        .H = willCarryInto(12, tgt_val, src_val),
        .C = willCarryInto(16, tgt_val, src_val),
    };
    cpu.reg._16.set(tgt, tgt_val +% src_val);
    return .{};
}

pub fn add__rw_IB(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{16}) {
    const tgt = op.arg0.rw;
    const offset = op.arg1.ib;
    const val = cpu.reg._16.get(tgt);
    cpu.reg.flags = .{
        .Z = false,
        .N = false,
        .H = willCarryInto(12, val, offset),
        .C = willCarryInto(16, val, offset),
    };
    cpu.reg._16.set(tgt, signedAdd(val, offset));
    return .{};
}

pub fn adc__rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    doAdcRr(cpu, op.arg0.rb, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn adc__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = cpu.reg._16.get(op.arg1.rw);
    doAdcRr(cpu, op.arg0.rb, mmu.get(addr));
    return .{};
}

pub fn adc__rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{8}) {
    doAdcRr(cpu, op.arg0.rb, op.arg1.ib);
    return .{};
}

pub fn sub__rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    doSubRr(cpu, op.arg0.rb, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn sub__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = cpu.reg._16.get(op.arg1.rw);
    doSubRr(cpu, op.arg0.rb, mmu.get(addr));
    return .{};
}

pub fn sub__rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{8}) {
    doSubRr(cpu, op.arg0.rb, op.arg1.ib);
    return .{};
}

pub fn sbc__rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    doSbcRr(cpu, op.arg0.rb, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn sbc__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = cpu.reg._16.get(op.arg1.rw);
    doSbcRr(cpu, op.arg0.rb, mmu.get(addr));
    return .{};
}

pub fn sbc__rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{8}) {
    doSbcRr(cpu, op.arg0.rb, op.arg1.ib);
    return .{};
}

pub fn and__rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    doAndRr(cpu, op.arg0.rb, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn and__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = cpu.reg._16.get(op.arg1.rw);
    doAndRr(cpu, op.arg0.rb, mmu.get(addr));
    return .{};
}

pub fn and__rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{8}) {
    doAndRr(cpu, op.arg0.rb, op.arg1.ib);
    return .{};
}

pub fn or___rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    doOrRr(cpu, op.arg0.rb, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn or___rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = cpu.reg._16.get(op.arg1.rw);
    doOrRr(cpu, op.arg0.rb, mmu.get(addr));
    return .{};
}

pub fn or___rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{8}) {
    doOrRr(cpu, op.arg0.rb, op.arg1.ib);
    return .{};
}

pub fn xor__rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    doXorRr(cpu, op.arg0.rb, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn xor__rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = cpu.reg._16.get(op.arg1.rw);
    doXorRr(cpu, op.arg0.rb, mmu.get(addr));
    return .{};
}

pub fn xor__rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{8}) {
    doXorRr(cpu, op.arg0.rb, op.arg1.ib);
    return .{};
}

pub fn cp___rb_rb(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    doCpRr(cpu, op.arg0.rb, cpu.reg._8.get(op.arg1.rb));
    return .{};
}

pub fn cp___rb_RW(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{8}) {
    const addr = cpu.reg._16.get(op.arg1.rw);
    doCpRr(cpu, op.arg0.rb, mmu.get(addr));
    return .{};
}

pub fn cp___rb_ib(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(2, .{8}) {
    doCpRr(cpu, op.arg0.rb, op.arg1.ib);
    return .{};
}

pub fn cpl__rb___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{4}) {
    const tgt = op.arg0.rb;
    const val = cpu.reg._8.get(tgt);
    cpu.reg.flags = .{
        .Z = cpu.reg.flags.Z,
        .N = true,
        .H = 1,
        .C = cpu.reg.flags.C,
    };
    cpu.reg._8.set(tgt, ~val);
    return .{};
}

pub fn push_rw___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{16}) {
    push16(cpu, mmu, cpu.reg._16.get(op.arg0.rw));
    return .{};
}

pub fn pop__rw___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Result(1, .{12}) {
    cpu.reg._16.set(op.arg0.rw, pop16(cpu, mmu));
    // Always setting is faster than if check
    cpu.reg.flags._pad = 0;
    return .{};
}

// -- internal

fn willCarryInto(size: u5, a: i32, b: i32) u1 {
    if (a < 0 or b < 0) {
        return 0;
    }
    const mask = (@as(u32, 1) << size) - 1;
    return @boolToInt((@intCast(u32, a) & mask) + (@intCast(u32, b) & mask) > mask);
}

fn willBorrowFrom(size: u5, a: u16, b: u16) u1 {
    const mask = (@as(u32, 1) << size) - 1;
    return @boolToInt((a & mask) < (b & mask));
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
    push8(cpu, mmu, @truncate(u8, val >> 8));
    push8(cpu, mmu, @truncate(u8, val >> 0));
}

pub const Bit = struct {
    pub fn get(data: u8, bit: u3) u1 {
        return @truncate(u1, data >> bit);
    }
};

// TODO: maybe rename? Not too obvious...
pub fn flagShift(cpu: *main.Cpu, val: u8, carry: u1) u8 {
    cpu.reg.flags = .{
        .Z = val == 0,
        .N = false,
        .H = 0,
        .C = carry,
    };
    return val;
}

pub fn doRlc(cpu: *main.Cpu, val: u8) u8 {
    const msb = Bit.get(val, 7);
    return flagShift(cpu, val << 1 | msb, msb);
}

pub fn doRrc(cpu: *main.Cpu, val: u8) u8 {
    const lsb = Bit.get(val, 0);
    return flagShift(cpu, val >> 1 | (@as(u8, lsb) << 7), lsb);
}

pub fn doRl(cpu: *main.Cpu, val: u8) u8 {
    const msb = Bit.get(val, 7);
    return flagShift(cpu, val << 1 | cpu.reg.flags.C, msb);
}

pub fn doRr(cpu: *main.Cpu, val: u8) u8 {
    const lsb = Bit.get(val, 0);
    return flagShift(cpu, val >> 1 | @as(u8, cpu.reg.flags.C) << 7, lsb);
}

fn doAddRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg.flags = .{
        .Z = (tgt_val +% val) == 0,
        .N = false,
        .H = willCarryInto(4, tgt_val, val),
        .C = willCarryInto(8, tgt_val, val),
    };
    cpu.reg._8.set(tgt, tgt_val +% val);
}

fn doAdcRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    const carry = cpu.reg.flags.C;
    cpu.reg.flags = .{
        .Z = (tgt_val +% val +% carry) == 0,
        .N = false,
        .H = willCarryInto(4, tgt_val, val) | willCarryInto(4, tgt_val, val +% carry),
        .C = willCarryInto(8, tgt_val, val) | willCarryInto(8, tgt_val, val +% carry),
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
    const carry = cpu.reg.flags.C;
    cpu.reg.flags = .{
        .Z = (tgt_val -% val -% carry) == 0,
        .N = true,
        .H = willBorrowFrom(4, tgt_val, val) | willBorrowFrom(4, tgt_val -% val, carry),
        .C = willBorrowFrom(8, tgt_val, val) | willBorrowFrom(8, tgt_val -% val, carry),
    };
    cpu.reg._8.set(tgt, tgt_val -% val -% carry);
}

fn doCpRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg.flags = .{
        .Z = (tgt_val -% val) == 0,
        .N = true,
        .H = willBorrowFrom(4, tgt_val, val),
        .C = willBorrowFrom(8, tgt_val, val),
    };
}

fn doAndRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg.flags = .{
        .Z = (tgt_val & val) == 0,
        .N = false,
        .H = 1,
        .C = 0,
    };
    cpu.reg._8.set(tgt, tgt_val & val);
}

fn doOrRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg._8.set(tgt, flagShift(cpu, tgt_val | val, 0));
}

fn doXorRr(cpu: *main.Cpu, tgt: Reg8, val: u8) void {
    const tgt_val = cpu.reg._8.get(tgt);
    cpu.reg._8.set(tgt, flagShift(cpu, tgt_val ^ val, 0));
}

fn signedAdd(a: u16, b: u8) u16 {
    const signed = @bitCast(i16, a) +% @bitCast(i8, b);
    return @bitCast(u16, signed);
}
