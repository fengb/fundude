const std = @import("std");
const main = @import("main.zig");
const op = @import("cpu_op.zig");
const irq = @import("irq.zig");
const util = @import("util.zig");

pub const Result = op.Result;
const Op = op.Op;

pub const Mode = enum(u16) {
    norm,
    halt,
    stop,
    illegal,
    fatal, // Not a GB mode, this code is bad and we should feel bad
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

pub const Flags = packed struct {
    _pad: u4 = 0,
    C: bool,
    H: bool,
    N: bool,
    Z: bool,

    pub fn c(self: Flags, comptime T: type) T {
        return @boolToInt(self.C);
    }
};

pub const Cpu = struct {
    mode: Mode,
    interrupt_master: bool,

    reg: packed union {
        _16: util.EnumArray(Reg16, u16),
        _8: util.EnumArray(Reg8, u8),
        flags: Flags,
    },

    pub fn reset(self: *Cpu) void {
        self.mode = .norm;
        self.interrupt_master = false;
        self.reg._16.set(.PC, 0);
    }

    pub fn step(self: *Cpu, mmu: *main.Mmu) Result {
        if (self.irqStep(mmu)) |res| {
            return res;
        } else if (self.mode == .halt) {
            return .{ .duration = 4 };
        } else {
            // TODO: optimize
            return self.opStep(mmu, mmu.ptr(self.reg._16.get(.PC)));
        }
    }

    fn irqStep(self: *Cpu, mmu: *main.Mmu) ?Result {
        if (!self.interrupt_master) return null;

        const cmp = mmu.dyn.io.IF.cmp(mmu.dyn.interrupt_enable);
        const addr: u16 = blk: {
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
                break :blk 0x40 + @as(u16, 8) * @enumToInt(active);
            } else {
                return null;
            }
        };

        self.mode = .norm;
        self.interrupt_master = false;
        // TODO: this is silly -- we reverse the hacked offset in OP CALL
        const dirty_pc = self.reg._16.get(.PC);
        self.reg._16.set(.PC, dirty_pc - 3);

        return @bitCast(Result, op.cal_IW___(self, mmu, addr));
    }

    fn opDecode(inst: u8, arg1: u8, arg2: u8) Op {
        const argw = @intCast(u16, arg2) << 8 | arg1;
        return switch (inst) {
            0x00 => Op._____(.nop______),
            0x01 => Op.rw_iw(.ld__rw_iw, .BC, argw),
            0x02 => Op.rw_rb(.ld__RW_rb, .BC, .A),
            0x03 => Op.rw___(.inc_rw___, .BC),
            0x04 => Op.rb___(.inc_rb___, .B),
            0x05 => Op.rb___(.dec_rb___, .B),
            0x06 => Op.rb_ib(.ld__rb_ib, .B, arg1),
            0x07 => Op.rb___(.rlc_rb___, .A),
            0x08 => Op.iw_rw(.ld__IW_rw, argw, .SP),
            0x09 => Op.rw_rw(.add_rw_rw, .HL, .BC),
            0x0A => Op.rb_rw(.ld__rb_RW, .A, .BC),
            0x0B => Op.rw___(.dec_rw___, .BC),
            0x0C => Op.rb___(.inc_rb___, .C),
            0x0D => Op.rb___(.dec_rb___, .C),
            0x0E => Op.rb_ib(.ld__rb_ib, .C, arg1),
            0x0F => Op.rb___(.rrc_rb___, .A),

            0x10 => Op.mo___(.sys_mo___, .stop),
            0x11 => Op.rw_iw(.ld__rw_iw, .DE, argw),
            0x12 => Op.rw_rb(.ld__RW_rb, .DE, .A),
            0x13 => Op.rw___(.inc_rw___, .DE),
            0x14 => Op.rb___(.inc_rb___, .D),
            0x15 => Op.rb___(.dec_rb___, .D),
            0x16 => Op.rb_ib(.ld__rb_ib, .D, arg1),
            0x17 => Op.rb___(.rla_rb___, .A),
            0x18 => Op.ib___(.jr__IB___, arg1),
            0x19 => Op.rw_rw(.add_rw_rw, .HL, .DE),
            0x1A => Op.rb_rw(.ld__rb_RW, .A, .DE),
            0x1B => Op.rw___(.dec_rw___, .DE),
            0x1C => Op.rb___(.inc_rb___, .E),
            0x1D => Op.rb___(.dec_rb___, .E),
            0x1E => Op.rb_ib(.ld__rb_ib, .E, arg1),
            0x1F => Op.rb___(.rra_rb___, .A),

            0x20 => Op.zc_ib(.jr__zc_IB, .nz, arg1),
            0x21 => Op.rw_iw(.ld__rw_iw, .HL, argw),
            0x22 => Op.rw_rb(.ldi_RW_rb, .HL, .A),
            0x23 => Op.rw___(.inc_rw___, .HL),
            0x24 => Op.rb___(.inc_rb___, .H),
            0x25 => Op.rb___(.dec_rb___, .H),
            0x26 => Op.rb_ib(.ld__rb_ib, .H, arg1),
            0x27 => Op.rb___(.daa_rb___, .A),
            0x28 => Op.zc_ib(.jr__zc_IB, .z, arg1),
            0x29 => Op.rw_rw(.add_rw_rw, .HL, .HL),
            0x2A => Op.rb_rw(.ldi_rb_RW, .A, .HL),
            0x2B => Op.rw___(.dec_rw___, .HL),
            0x2C => Op.rb___(.inc_rb___, .L),
            0x2D => Op.rb___(.dec_rb___, .L),
            0x2E => Op.rb_ib(.ld__rb_ib, .L, arg1),
            0x2F => Op.rb___(.cpl_rb___, .A),

            0x30 => Op.zc_ib(.jr__zc_IB, .nc, arg1),
            0x31 => Op.rw_iw(.ld__rw_iw, .SP, argw),
            0x32 => Op.rw_rb(.ldd_RW_rb, .HL, .A),
            0x33 => Op.rw___(.inc_rw___, .SP),
            0x34 => Op.rw___(.inc_RW___, .HL),
            0x35 => Op.rw___(.dec_RW___, .HL),
            0x36 => Op.rw_ib(.ld__RW_ib, .HL, arg1),
            0x37 => Op._____(.scf______),
            0x38 => Op.zc_ib(.jr__zc_IB, .c, arg1),
            0x39 => Op.rw_rw(.add_rw_rw, .HL, .SP),
            0x3A => Op.rb_rw(.ldd_rb_RW, .A, .HL),
            0x3B => Op.rw___(.dec_rw___, .SP),
            0x3C => Op.rb___(.inc_rb___, .A),
            0x3D => Op.rb___(.dec_rb___, .A),
            0x3E => Op.rb_ib(.ld__rb_ib, .A, arg1),
            0x3F => Op._____(.ccf______),

            0x40 => Op.rb_rb(.ld__rb_rb, .B, .B),
            0x41 => Op.rb_rb(.ld__rb_rb, .B, .C),
            0x42 => Op.rb_rb(.ld__rb_rb, .B, .D),
            0x43 => Op.rb_rb(.ld__rb_rb, .B, .E),
            0x44 => Op.rb_rb(.ld__rb_rb, .B, .H),
            0x45 => Op.rb_rb(.ld__rb_rb, .B, .L),
            0x46 => Op.rb_rw(.ld__rb_RW, .B, .HL),
            0x47 => Op.rb_rb(.ld__rb_rb, .B, .A),
            0x48 => Op.rb_rb(.ld__rb_rb, .C, .B),
            0x49 => Op.rb_rb(.ld__rb_rb, .C, .C),
            0x4A => Op.rb_rb(.ld__rb_rb, .C, .D),
            0x4B => Op.rb_rb(.ld__rb_rb, .C, .E),
            0x4C => Op.rb_rb(.ld__rb_rb, .C, .H),
            0x4D => Op.rb_rb(.ld__rb_rb, .C, .L),
            0x4E => Op.rb_rw(.ld__rb_RW, .C, .HL),
            0x4F => Op.rb_rb(.ld__rb_rb, .C, .A),

            0x50 => Op.rb_rb(.ld__rb_rb, .D, .B),
            0x51 => Op.rb_rb(.ld__rb_rb, .D, .C),
            0x52 => Op.rb_rb(.ld__rb_rb, .D, .D),
            0x53 => Op.rb_rb(.ld__rb_rb, .D, .E),
            0x54 => Op.rb_rb(.ld__rb_rb, .D, .H),
            0x55 => Op.rb_rb(.ld__rb_rb, .D, .L),
            0x56 => Op.rb_rw(.ld__rb_RW, .D, .HL),
            0x57 => Op.rb_rb(.ld__rb_rb, .D, .A),
            0x58 => Op.rb_rb(.ld__rb_rb, .E, .B),
            0x59 => Op.rb_rb(.ld__rb_rb, .E, .C),
            0x5A => Op.rb_rb(.ld__rb_rb, .E, .D),
            0x5B => Op.rb_rb(.ld__rb_rb, .E, .E),
            0x5C => Op.rb_rb(.ld__rb_rb, .E, .H),
            0x5D => Op.rb_rb(.ld__rb_rb, .E, .L),
            0x5E => Op.rb_rw(.ld__rb_RW, .E, .HL),
            0x5F => Op.rb_rb(.ld__rb_rb, .E, .A),

            0x60 => Op.rb_rb(.ld__rb_rb, .H, .B),
            0x61 => Op.rb_rb(.ld__rb_rb, .H, .C),
            0x62 => Op.rb_rb(.ld__rb_rb, .H, .D),
            0x63 => Op.rb_rb(.ld__rb_rb, .H, .E),
            0x64 => Op.rb_rb(.ld__rb_rb, .H, .H),
            0x65 => Op.rb_rb(.ld__rb_rb, .H, .L),
            0x66 => Op.rb_rw(.ld__rb_RW, .H, .HL),
            0x67 => Op.rb_rb(.ld__rb_rb, .H, .A),
            0x68 => Op.rb_rb(.ld__rb_rb, .L, .B),
            0x69 => Op.rb_rb(.ld__rb_rb, .L, .C),
            0x6A => Op.rb_rb(.ld__rb_rb, .L, .D),
            0x6B => Op.rb_rb(.ld__rb_rb, .L, .E),
            0x6C => Op.rb_rb(.ld__rb_rb, .L, .H),
            0x6D => Op.rb_rb(.ld__rb_rb, .L, .L),
            0x6E => Op.rb_rw(.ld__rb_RW, .L, .HL),
            0x6F => Op.rb_rb(.ld__rb_rb, .L, .A),

            0x70 => Op.rw_rb(.ld__RW_rb, .HL, .B),
            0x71 => Op.rw_rb(.ld__RW_rb, .HL, .C),
            0x72 => Op.rw_rb(.ld__RW_rb, .HL, .D),
            0x73 => Op.rw_rb(.ld__RW_rb, .HL, .E),
            0x74 => Op.rw_rb(.ld__RW_rb, .HL, .H),
            0x75 => Op.rw_rb(.ld__RW_rb, .HL, .L),
            0x76 => Op.mo___(.sys_mo___, .halt),
            0x77 => Op.rw_rb(.ld__RW_rb, .HL, .A),
            0x78 => Op.rb_rb(.ld__rb_rb, .A, .B),
            0x79 => Op.rb_rb(.ld__rb_rb, .A, .C),
            0x7A => Op.rb_rb(.ld__rb_rb, .A, .D),
            0x7B => Op.rb_rb(.ld__rb_rb, .A, .E),
            0x7C => Op.rb_rb(.ld__rb_rb, .A, .H),
            0x7D => Op.rb_rb(.ld__rb_rb, .A, .L),
            0x7E => Op.rb_rw(.ld__rb_RW, .A, .HL),
            0x7F => Op.rb_rb(.ld__rb_rb, .A, .A),

            0x80 => Op.rb_rb(.add_rb_rb, .A, .B),
            0x81 => Op.rb_rb(.add_rb_rb, .A, .C),
            0x82 => Op.rb_rb(.add_rb_rb, .A, .D),
            0x83 => Op.rb_rb(.add_rb_rb, .A, .E),
            0x84 => Op.rb_rb(.add_rb_rb, .A, .H),
            0x85 => Op.rb_rb(.add_rb_rb, .A, .L),
            0x86 => Op.rb_rw(.add_rb_RW, .A, .HL),
            0x87 => Op.rb_rb(.add_rb_rb, .A, .A),
            0x88 => Op.rb_rb(.adc_rb_rb, .A, .B),
            0x89 => Op.rb_rb(.adc_rb_rb, .A, .C),
            0x8A => Op.rb_rb(.adc_rb_rb, .A, .D),
            0x8B => Op.rb_rb(.adc_rb_rb, .A, .E),
            0x8C => Op.rb_rb(.adc_rb_rb, .A, .H),
            0x8D => Op.rb_rb(.adc_rb_rb, .A, .L),
            0x8E => Op.rb_rw(.adc_rb_RW, .A, .HL),
            0x8F => Op.rb_rb(.adc_rb_rb, .A, .A),

            0x90 => Op.rb_rb(.sub_rb_rb, .A, .B),
            0x91 => Op.rb_rb(.sub_rb_rb, .A, .C),
            0x92 => Op.rb_rb(.sub_rb_rb, .A, .D),
            0x93 => Op.rb_rb(.sub_rb_rb, .A, .E),
            0x94 => Op.rb_rb(.sub_rb_rb, .A, .H),
            0x95 => Op.rb_rb(.sub_rb_rb, .A, .L),
            0x96 => Op.rb_rw(.sub_rb_RW, .A, .HL),
            0x97 => Op.rb_rb(.sub_rb_rb, .A, .A),
            0x98 => Op.rb_rb(.sbc_rb_rb, .A, .B),
            0x99 => Op.rb_rb(.sbc_rb_rb, .A, .C),
            0x9A => Op.rb_rb(.sbc_rb_rb, .A, .D),
            0x9B => Op.rb_rb(.sbc_rb_rb, .A, .E),
            0x9C => Op.rb_rb(.sbc_rb_rb, .A, .H),
            0x9D => Op.rb_rb(.sbc_rb_rb, .A, .L),
            0x9E => Op.rb_rw(.sbc_rb_RW, .A, .HL),
            0x9F => Op.rb_rb(.sbc_rb_rb, .A, .A),

            0xA0 => Op.rb_rb(.and_rb_rb, .A, .B),
            0xA1 => Op.rb_rb(.and_rb_rb, .A, .C),
            0xA2 => Op.rb_rb(.and_rb_rb, .A, .D),
            0xA3 => Op.rb_rb(.and_rb_rb, .A, .E),
            0xA4 => Op.rb_rb(.and_rb_rb, .A, .H),
            0xA5 => Op.rb_rb(.and_rb_rb, .A, .L),
            0xA6 => Op.rb_rw(.and_rb_RW, .A, .HL),
            0xA7 => Op.rb_rb(.and_rb_rb, .A, .A),
            0xA8 => Op.rb_rb(.xor_rb_rb, .A, .B),
            0xA9 => Op.rb_rb(.xor_rb_rb, .A, .C),
            0xAA => Op.rb_rb(.xor_rb_rb, .A, .D),
            0xAB => Op.rb_rb(.xor_rb_rb, .A, .E),
            0xAC => Op.rb_rb(.xor_rb_rb, .A, .H),
            0xAD => Op.rb_rb(.xor_rb_rb, .A, .L),
            0xAE => Op.rb_rw(.xor_rb_RW, .A, .HL),
            0xAF => Op.rb_rb(.xor_rb_rb, .A, .A),

            0xB0 => Op.rb_rb(.or__rb_rb, .A, .B),
            0xB1 => Op.rb_rb(.or__rb_rb, .A, .C),
            0xB2 => Op.rb_rb(.or__rb_rb, .A, .D),
            0xB3 => Op.rb_rb(.or__rb_rb, .A, .E),
            0xB4 => Op.rb_rb(.or__rb_rb, .A, .H),
            0xB5 => Op.rb_rb(.or__rb_rb, .A, .L),
            0xB6 => Op.rb_rw(.or__rb_RW, .A, .HL),
            0xB7 => Op.rb_rb(.or__rb_rb, .A, .A),
            0xB8 => Op.rb_rb(.cp__rb_rb, .A, .B),
            0xB9 => Op.rb_rb(.cp__rb_rb, .A, .C),
            0xBA => Op.rb_rb(.cp__rb_rb, .A, .D),
            0xBB => Op.rb_rb(.cp__rb_rb, .A, .E),
            0xBC => Op.rb_rb(.cp__rb_rb, .A, .H),
            0xBD => Op.rb_rb(.cp__rb_rb, .A, .L),
            0xBE => Op.rb_rw(.cp__rb_RW, .A, .HL),
            0xBF => Op.rb_rb(.cp__rb_rb, .A, .A),

            0xC0 => Op.zc___(.ret_zc___, .nz),
            0xC1 => Op.rw___(.pop_rw___, .BC),
            0xC2 => Op.zc_iw(.jp__zc_IW, .nz, argw),
            0xC3 => Op.iw___(.jp__IW___, argw),
            0xC4 => Op.zc_iw(.cal_zc_IW, .nz, argw),
            0xC5 => Op.rw___(.psh_rw___, .BC),
            0xC6 => Op.rb_ib(.add_rb_ib, .A, arg1),
            0xC7 => Op.ib___(.rst_ib___, 0x00),
            0xC8 => Op.zc___(.ret_zc___, .z),
            0xC9 => Op._____(.ret______),
            0xCA => Op.zc_iw(.jp__zc_IW, .z, argw),
            0xCB => Op._____(.cb), // TODO
            0xCC => Op.zc_iw(.cal_zc_IW, .z, argw),
            0xCD => Op.iw___(.cal_IW___, argw),
            0xCE => Op.rb_ib(.adc_rb_ib, .A, arg1),
            0xCF => Op.ib___(.rst_ib___, 0x08),

            0xD0 => Op.zc___(.ret_zc___, .nc),
            0xD1 => Op.rw___(.pop_rw___, .DE),
            0xD2 => Op.zc_iw(.jp__zc_IW, .nc, argw),
            0xD3 => Op._____(.ILLEGAL__),
            0xD4 => Op.zc_iw(.cal_zc_IW, .nc, argw),
            0xD5 => Op.rw___(.psh_rw___, .DE),
            0xD6 => Op.rb_ib(.sub_rb_ib, .A, arg1),
            0xD7 => Op.ib___(.rst_ib___, 0x10),
            0xD8 => Op.zc___(.ret_zc___, .c),
            0xD9 => Op._____(.rti______),
            0xDA => Op.zc_iw(.jp__zc_IW, .c, argw),
            0xDB => Op._____(.ILLEGAL__),
            0xDC => Op.zc_iw(.cal_zc_IW, .c, argw),
            0xDD => Op._____(.ILLEGAL__),
            0xDE => Op.rb_ib(.sbc_rb_ib, .A, arg1),
            0xDF => Op.ib___(.rst_ib___, 0x18),

            0xE0 => Op.ib_rb(.ldh_IB_rb, arg1, .A),
            0xE1 => Op.rw___(.pop_rw___, .HL),
            0xE2 => Op.rb_rb(.ld__RB_rb, .C, .A),
            0xE3 => Op._____(.ILLEGAL__),
            0xE4 => Op._____(.ILLEGAL__),
            0xE5 => Op.rw___(.psh_rw___, .HL),
            0xE6 => Op.rb_ib(.and_rb_ib, .A, arg1),
            0xE7 => Op.ib___(.rst_ib___, 0x20),
            0xE8 => Op.rw_ib(.add_rw_IB, .SP, arg1),
            0xE9 => Op.rw___(.jp__RW___, .HL),
            0xEA => Op.iw_rb(.ld__IW_rb, argw, .A),
            0xEB => Op._____(.ILLEGAL__),
            0xEC => Op._____(.ILLEGAL__),
            0xED => Op._____(.ILLEGAL__),
            0xEE => Op.rb_ib(.xor_rb_ib, .A, arg1),
            0xEF => Op.ib___(.rst_ib___, 0x28),

            0xF0 => Op.rb_ib(.ldh_rb_IB, .A, arg1),
            0xF1 => Op.rw___(.pop_rw___, .AF),
            0xF2 => Op.rb_rb(.ld__rb_RB, .A, .C),
            0xF3 => Op.tf___(.int_tf___, false),
            0xF4 => Op._____(.ILLEGAL__),
            0xF5 => Op.rw___(.psh_rw___, .AF),
            0xF6 => Op.rb_ib(.or__rb_ib, .A, arg1),
            0xF7 => Op.ib___(.rst_ib___, 0x30),
            0xF8 => Op.rw_ib(.ldh_rw_IB, .SP, arg1),
            0xF9 => Op.rw_rw(.ld__rw_rw, .SP, .HL),
            0xFA => Op.rb_iw(.ld__rb_IW, .A, argw),
            0xFB => Op.tf___(.int_tf___, true),
            0xFC => Op._____(.ILLEGAL__),
            0xFD => Op._____(.ILLEGAL__),
            0xFE => Op.rb_ib(.cp__rb_ib, .A, arg1),
            0xFF => Op.ib___(.rst_ib___, 0x38),
        };
    }

    fn opStep(cpu: *Cpu, mmu: *main.Mmu, inst: [*]const u8) Result {
        const thing = opDecode(inst[0], inst[1], inst[2]);
        inline for (std.meta.fields(op.Id)) |field| {
            if (field.value == @enumToInt(thing.id)) {
                const func = @field(op, field.name);
                return .{ .duration = 4 }; // FIXME
            }
        }
        unreachable;
    }
};
