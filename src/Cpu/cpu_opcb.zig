const main = @import("../main.zig");
const Op = @import("Op.zig");

const Reg8 = main.Cpu.Reg8;

const Result = struct {
    name: []const u8,
    val: u8,
};

fn cb_rlc(cpu: *main.Cpu, val: u8) Result {
    return Result{ .name = "RLC", .val = Op.impl.doRlc(cpu, val) };
}

fn cb_rrc(cpu: *main.Cpu, val: u8) Result {
    return Result{ .name = "RRC", .val = Op.impl.doRrc(cpu, val) };
}

fn cb_rl(cpu: *main.Cpu, val: u8) Result {
    return Result{ .name = "RL", .val = Op.impl.doRl(cpu, val) };
}

fn cb_rr(cpu: *main.Cpu, val: u8) Result {
    return Result{ .name = "RR", .val = Op.impl.doRr(cpu, val) };
}

fn cb_sla(cpu: *main.Cpu, val: u8) Result {
    return Result{ .name = "SLA", .val = Op.impl.flagShift(cpu, val << 1, impl.Bit.get(val, 7)) };
}

fn cb_sra(cpu: *main.Cpu, val: u8) Result {
    const msb = val & 0b10000000;
    return Result{ .name = "SLA", .val = Op.impl.flagShift(cpu, msb | val >> 1, impl.Bit.get(val, 0)) };
}

fn cb_swap(cpu: *main.Cpu, val: u8) Result {
    const hi = val >> 4;
    const lo = val & 0xF;
    return Result{ .name = "SLA", .val = Op.impl.flagShift(cpu, lo << 4 | hi, 0) };
}

fn cb_srl(cpu: *main.Cpu, val: u8) Result {
    return Result{ .name = "SLA", .val = Op.impl.flagShift(cpu, val >> 1, impl.Bit.get(val, 0)) };
}

fn nameGlue(comptime prefix: []const u8, val: u3) []const u8 {
    return switch (val) {
        0 => prefix ++ " 0",
        1 => prefix ++ " 1",
        2 => prefix ++ " 2",
        3 => prefix ++ " 3",
        4 => prefix ++ " 4",
        5 => prefix ++ " 5",
        6 => prefix ++ " 6",
        7 => prefix ++ " 7",
    };
}

fn cb_bit(cpu: *main.Cpu, val: u8, bit: u3) Result {
    cpu.reg.flags = .{
        .Z = Op.impl.Bit.get(val, bit) == 0,
        .N = false,
        .H = 1,
        .C = cpu.reg.flags.C,
    };
    return Result{ .name = nameGlue("BIT", bit), .val = val };
}

fn cb_res(cpu: *main.Cpu, val: u8, bit: u3) Result {
    const mask = ~(@as(u8, 1) << bit);
    return Result{ .name = nameGlue("RES", bit), .val = val & mask };
}

fn cb_set(cpu: *main.Cpu, val: u8, bit: u3) Result {
    const mask = @as(u8, 1) << bit;
    return Result{ .name = nameGlue("SET", bit), .val = val | mask };
}

fn cb_tgt(cpu: *main.Cpu, op: u8) ?Reg8 {
    return switch (op & 7) {
        0 => Reg8.B,
        1 => Reg8.C,
        2 => Reg8.D,
        3 => Reg8.E,
        4 => Reg8.H,
        5 => Reg8.L,
        6 => null,
        7 => Reg8.A,
        else => unreachable,
    };
}

fn cb_run(cpu: *main.Cpu, op: u8, val: u8) Result {
    return switch (op & 0xF8) {
        0x00 => cb_rlc(cpu, val),
        0x08 => cb_rrc(cpu, val),
        0x10 => cb_rl(cpu, val),
        0x18 => cb_rr(cpu, val),
        0x20 => cb_sla(cpu, val),
        0x28 => cb_sra(cpu, val),
        0x30 => cb_swap(cpu, val),
        0x38 => cb_srl(cpu, val),

        0x40 => cb_bit(cpu, val, 0),
        0x48 => cb_bit(cpu, val, 1),
        0x50 => cb_bit(cpu, val, 2),
        0x58 => cb_bit(cpu, val, 3),
        0x60 => cb_bit(cpu, val, 4),
        0x68 => cb_bit(cpu, val, 5),
        0x70 => cb_bit(cpu, val, 6),
        0x78 => cb_bit(cpu, val, 7),

        0x80 => cb_res(cpu, val, 0),
        0x88 => cb_res(cpu, val, 1),
        0x90 => cb_res(cpu, val, 2),
        0x98 => cb_res(cpu, val, 3),
        0xA0 => cb_res(cpu, val, 4),
        0xA8 => cb_res(cpu, val, 5),
        0xB0 => cb_res(cpu, val, 6),
        0xB8 => cb_res(cpu, val, 7),

        0xC0 => cb_set(cpu, val, 0),
        0xC8 => cb_set(cpu, val, 1),
        0xD0 => cb_set(cpu, val, 2),
        0xD8 => cb_set(cpu, val, 3),
        0xE0 => cb_set(cpu, val, 4),
        0xE8 => cb_set(cpu, val, 5),
        0xF0 => cb_set(cpu, val, 6),
        0xF8 => cb_set(cpu, val, 7),
        else => unreachable,
    };
}

pub fn cb___ib___(cpu: *main.Cpu, mmu: *main.Mmu, op: Op) Op.impl.Result(2, .{ 8, 16 }) {
    const arg = op.arg0.ib;
    const tgt = cb_tgt(cpu, arg);
    if (tgt) |reg| {
        const val = cpu.reg._8.get(reg);
        const res = cb_run(cpu, arg, val);
        cpu.reg._8.set(reg, res.val);
        //return Op.Result{ .name = res.name, .length = 2, .duration = 8 };
        return .{ .duration = 8 };
    } else {
        const addr = cpu.reg._16.get(.HL);
        const res = cb_run(cpu, arg, mmu.get(addr));
        mmu.set(addr, res.val);
        //return Op.Result{ .name = res.name, .length = 2, .duration = 16 };
        return .{ .duration = 16 };
    }
}
