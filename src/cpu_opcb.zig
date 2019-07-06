const base = @import("base.zig");
const cpu_op = @import("cpu_op.zig");

const Reg8 = base.cpu.Reg8;
const Flags = base.cpu.Flags;

const Result = struct {
    name: []const u8,
    val: u8,
};

fn cb_rlc(cpu: *base.Cpu, val: u8) Result {
    return Result{ .name = "RLC", .val = cpu_op.doRlc(cpu, val) };
}

fn cb_rrc(cpu: *base.Cpu, val: u8) Result {
    return Result{ .name = "RRC", .val = cpu_op.doRrc(cpu, val) };
}

fn cb_rl(cpu: *base.Cpu, val: u8) Result {
    return Result{ .name = "RL", .val = cpu_op.doRl(cpu, val) };
}

fn cb_rr(cpu: *base.Cpu, val: u8) Result {
    return Result{ .name = "RR", .val = cpu_op.doRr(cpu, val) };
}

fn cb_sla(cpu: *base.Cpu, val: u8) Result {
    return Result{ .name = "SLA", .val = cpu_op.flagShift(cpu, val << 1, val >> 7 != 0) };
}

fn cb_sra(cpu: *base.Cpu, val: u8) Result {
    const msb = val & 0b10000000;
    return Result{ .name = "SLA", .val = cpu_op.flagShift(cpu, msb | val >> 1, val & 1 != 0) };
}

fn cb_swap(cpu: *base.Cpu, val: u8) Result {
    const hi = val >> 4;
    const lo = val & 0xF;
    return Result{ .name = "SLA", .val = cpu_op.flagShift(cpu, lo << 4 | hi, false) };
}

fn cb_srl(cpu: *base.Cpu, val: u8) Result {
    return Result{ .name = "SLA", .val = cpu_op.flagShift(cpu, val >> 1, val & 1 != 0) };
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

fn cb_bit(cpu: *base.Cpu, val: u8, bit: u3) Result {
    cpu.reg.flags = Flags{
        .Z = cpu_op.Bit.get(val, bit) == 0,
        .N = false,
        .H = true,
        .C = cpu.reg.flags.C,
    };
    return Result{ .name = nameGlue("BIT", bit), .val = val };
}

fn cb_res(cpu: *base.Cpu, val: u8, bit: u3) Result {
    const mask = ~(u8(1) << bit);
    return Result{ .name = nameGlue("RES", bit), .val = val & mask };
}

fn cb_set(cpu: *base.Cpu, val: u8, bit: u3) Result {
    const mask = u8(1) << bit;
    return Result{ .name = nameGlue("SET", bit), .val = val | mask };
}

fn cb_tgt(cpu: *base.Cpu, op: u8) ?*Reg8 {
    return switch (op & 7) {
        0 => &cpu.reg._16.BC.x._0,
        1 => &cpu.reg._16.BC.x._1,
        2 => &cpu.reg._16.DE.x._0,
        3 => &cpu.reg._16.DE.x._1,
        4 => &cpu.reg._16.HL.x._0,
        5 => &cpu.reg._16.HL.x._1,
        6 => null,
        7 => &cpu.reg._16.AF.x._0,
        else => unreachable,
    };
}

fn cb_run(cpu: *base.Cpu, op: u8, val: u8) Result {
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

pub fn cb(cpu: *base.Cpu, mmu: *base.Mmu, op: u8) cpu_op.Result {
    var tgt = cb_tgt(cpu, op);
    if (tgt) |reg| {
        const res = cb_run(cpu, op, reg._);
        reg._ = res.val;
        return cpu_op.Result{ .name = res.name, .length = 2, .duration = 8 };
    } else {
        const res = cb_run(cpu, op, mmu.get(cpu.reg._16.HL._));
        mmu.set(cpu.reg._16.HL._, res.val);
        return cpu_op.Result{ .name = res.name, .length = 2, .duration = 16 };
    }
}
