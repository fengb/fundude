const base = @import("base.zig");
const op = @import("cpu_op.zig");
const irq = @import("irq.zig");
const util = @import("util.zig");

pub const Result = op.Result;

pub const Mode = enum {
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
        return if (self.C) T(1) else 0;
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

    pub fn step(self: *Cpu, mmu: *base.Mmu) Result {
        if (self.irqStep(mmu)) |res| {
            return res;
        } else if (self.mode == .halt) {
            return base.cpu.Result{
                .name = "SKIP",
                .length = 0,
                .duration = 4,
            };
        } else {
            // TODO: optimize
            return self.opStep(mmu, mmu.ptr(self.reg._16.get(.PC)));
        }
    }

    fn irqStep(self: *Cpu, mmu: *base.Mmu) ?Result {
        if (!self.interrupt_master) {
            return null;
        }

        const OP_CALL = 0xCD;
        const cmp = mmu.dyn.io.IF.cmp(mmu.dyn.interrupt_enable);
        const addr = switch (cmp.active() orelse return null) {
            .vblank => blk: {
                mmu.dyn.io.IF.vblank = false;
                break :blk u8(0x40);
            },
            .lcd_stat => blk: {
                mmu.dyn.io.IF.lcd_stat = false;
                break :blk u8(0x48);
            },
            .timer => blk: {
                mmu.dyn.io.IF.timer = false;
                break :blk u8(0x50);
            },
            .serial => blk: {
                mmu.dyn.io.IF.serial = false;
                break :blk u8(0x58);
            },
            .joypad => blk: {
                mmu.dyn.io.IF.joypad = false;
                break :blk u8(0x60);
            },
        };

        self.mode = .norm;
        self.interrupt_master = false;
        // TODO: this is silly -- we reverse the hacked offset in OP CALL
        const dirty_pc = self.reg._16.get(.PC);
        self.reg._16.set(.PC, dirty_pc - 3);

        const inst = [_]u8{ OP_CALL, addr, 0 };
        return self.opStep(mmu, &inst);
    }

    fn opStep(cpu: *Cpu, mmu: *base.Mmu, inst: [*]const u8) Result {
        return switch (inst[0]) {
            0x00 => op.nop(cpu, mmu),
            0x01 => op.ld__ww_df(cpu, mmu, .BC, with16(inst)),
            0x02 => op.ld__WW_rr(cpu, mmu, .BC, .A),
            0x03 => op.inc_ww___(cpu, mmu, .BC),
            0x04 => op.inc_rr___(cpu, mmu, .B),
            0x05 => op.dec_rr___(cpu, mmu, .B),
            0x06 => op.ld__rr_d8(cpu, mmu, .B, with8(inst)),
            0x07 => op.rlc_rr___(cpu, mmu, .A),
            0x08 => op.ld__AF_ww(cpu, mmu, with16(inst), .SP),
            0x09 => op.add_ww_ww(cpu, mmu, .HL, .BC),
            0x0A => op.ld__rr_WW(cpu, mmu, .A, .BC),
            0x0B => op.dec_ww___(cpu, mmu, .BC),
            0x0C => op.inc_rr___(cpu, mmu, .C),
            0x0D => op.dec_rr___(cpu, mmu, .C),
            0x0E => op.ld__rr_d8(cpu, mmu, .C, with8(inst)),
            0x0F => op.rrc_rr___(cpu, mmu, .A),

            0x10 => op.sys(cpu, mmu, .stop),
            0x11 => op.ld__ww_df(cpu, mmu, .DE, with16(inst)),
            0x12 => op.ld__WW_rr(cpu, mmu, .DE, .A),
            0x13 => op.inc_ww___(cpu, mmu, .DE),
            0x14 => op.inc_rr___(cpu, mmu, .D),
            0x15 => op.dec_rr___(cpu, mmu, .D),
            0x16 => op.ld__rr_d8(cpu, mmu, .D, with8(inst)),
            0x17 => op.rla_rr___(cpu, mmu, .A),
            0x18 => op.jr__R8___(cpu, mmu, with8(inst)),
            0x19 => op.add_ww_ww(cpu, mmu, .HL, .DE),
            0x1A => op.ld__rr_WW(cpu, mmu, .A, .DE),
            0x1B => op.dec_ww___(cpu, mmu, .DE),
            0x1C => op.inc_rr___(cpu, mmu, .E),
            0x1D => op.dec_rr___(cpu, mmu, .E),
            0x1E => op.ld__rr_d8(cpu, mmu, .E, with8(inst)),
            0x1F => op.rra_rr___(cpu, mmu, .A),

            0x20 => op.jr__if_R8(cpu, mmu, .nz, with8(inst)),
            0x21 => op.ld__ww_df(cpu, mmu, .HL, with16(inst)),
            0x22 => op.ldi_WW_rr(cpu, mmu, .HL, .A),
            0x23 => op.inc_ww___(cpu, mmu, .HL),
            0x24 => op.inc_rr___(cpu, mmu, .H),
            0x25 => op.dec_rr___(cpu, mmu, .H),
            0x26 => op.ld__rr_d8(cpu, mmu, .H, with8(inst)),
            0x27 => op.daa_rr___(cpu, mmu, .A),
            0x28 => op.jr__if_R8(cpu, mmu, .z, with8(inst)),
            0x29 => op.add_ww_ww(cpu, mmu, .HL, .HL),
            0x2A => op.ldi_rr_WW(cpu, mmu, .A, .HL),
            0x2B => op.dec_ww___(cpu, mmu, .HL),
            0x2C => op.inc_rr___(cpu, mmu, .L),
            0x2D => op.dec_rr___(cpu, mmu, .L),
            0x2E => op.ld__rr_d8(cpu, mmu, .L, with8(inst)),
            0x2F => op.cpl_rr___(cpu, mmu, .A),

            0x30 => op.jr__if_R8(cpu, mmu, .nc, with8(inst)),
            0x31 => op.ld__ww_df(cpu, mmu, .SP, with16(inst)),
            0x32 => op.ldd_WW_rr(cpu, mmu, .HL, .A),
            0x33 => op.inc_ww___(cpu, mmu, .SP),
            0x34 => op.inc_WW___(cpu, mmu, .HL),
            0x35 => op.dec_WW___(cpu, mmu, .HL),
            0x36 => op.ld__WW_d8(cpu, mmu, .HL, with8(inst)),
            0x37 => op.scf(cpu, mmu),
            0x38 => op.jr__if_R8(cpu, mmu, .c, with8(inst)),
            0x39 => op.add_ww_ww(cpu, mmu, .HL, .SP),
            0x3A => op.ldd_rr_WW(cpu, mmu, .A, .HL),
            0x3B => op.dec_ww___(cpu, mmu, .SP),
            0x3C => op.inc_rr___(cpu, mmu, .A),
            0x3D => op.dec_rr___(cpu, mmu, .A),
            0x3E => op.ld__rr_d8(cpu, mmu, .A, with8(inst)),
            0x3F => op.ccf(cpu, mmu),

            0x40 => op.ld__rr_rr(cpu, mmu, .B, .B),
            0x41 => op.ld__rr_rr(cpu, mmu, .B, .C),
            0x42 => op.ld__rr_rr(cpu, mmu, .B, .D),
            0x43 => op.ld__rr_rr(cpu, mmu, .B, .E),
            0x44 => op.ld__rr_rr(cpu, mmu, .B, .H),
            0x45 => op.ld__rr_rr(cpu, mmu, .B, .L),
            0x46 => op.ld__rr_WW(cpu, mmu, .B, .HL),
            0x47 => op.ld__rr_rr(cpu, mmu, .B, .A),
            0x48 => op.ld__rr_rr(cpu, mmu, .C, .B),
            0x49 => op.ld__rr_rr(cpu, mmu, .C, .C),
            0x4A => op.ld__rr_rr(cpu, mmu, .C, .D),
            0x4B => op.ld__rr_rr(cpu, mmu, .C, .E),
            0x4C => op.ld__rr_rr(cpu, mmu, .C, .H),
            0x4D => op.ld__rr_rr(cpu, mmu, .C, .L),
            0x4E => op.ld__rr_WW(cpu, mmu, .C, .HL),
            0x4F => op.ld__rr_rr(cpu, mmu, .C, .A),

            0x50 => op.ld__rr_rr(cpu, mmu, .D, .B),
            0x51 => op.ld__rr_rr(cpu, mmu, .D, .C),
            0x52 => op.ld__rr_rr(cpu, mmu, .D, .D),
            0x53 => op.ld__rr_rr(cpu, mmu, .D, .E),
            0x54 => op.ld__rr_rr(cpu, mmu, .D, .H),
            0x55 => op.ld__rr_rr(cpu, mmu, .D, .L),
            0x56 => op.ld__rr_WW(cpu, mmu, .D, .HL),
            0x57 => op.ld__rr_rr(cpu, mmu, .D, .A),
            0x58 => op.ld__rr_rr(cpu, mmu, .E, .B),
            0x59 => op.ld__rr_rr(cpu, mmu, .E, .C),
            0x5A => op.ld__rr_rr(cpu, mmu, .E, .D),
            0x5B => op.ld__rr_rr(cpu, mmu, .E, .E),
            0x5C => op.ld__rr_rr(cpu, mmu, .E, .H),
            0x5D => op.ld__rr_rr(cpu, mmu, .E, .L),
            0x5E => op.ld__rr_WW(cpu, mmu, .E, .HL),
            0x5F => op.ld__rr_rr(cpu, mmu, .E, .A),

            0x60 => op.ld__rr_rr(cpu, mmu, .H, .B),
            0x61 => op.ld__rr_rr(cpu, mmu, .H, .C),
            0x62 => op.ld__rr_rr(cpu, mmu, .H, .D),
            0x63 => op.ld__rr_rr(cpu, mmu, .H, .E),
            0x64 => op.ld__rr_rr(cpu, mmu, .H, .H),
            0x65 => op.ld__rr_rr(cpu, mmu, .H, .L),
            0x66 => op.ld__rr_WW(cpu, mmu, .H, .HL),
            0x67 => op.ld__rr_rr(cpu, mmu, .H, .A),
            0x68 => op.ld__rr_rr(cpu, mmu, .L, .B),
            0x69 => op.ld__rr_rr(cpu, mmu, .L, .C),
            0x6A => op.ld__rr_rr(cpu, mmu, .L, .D),
            0x6B => op.ld__rr_rr(cpu, mmu, .L, .E),
            0x6C => op.ld__rr_rr(cpu, mmu, .L, .H),
            0x6D => op.ld__rr_rr(cpu, mmu, .L, .L),
            0x6E => op.ld__rr_WW(cpu, mmu, .L, .HL),
            0x6F => op.ld__rr_rr(cpu, mmu, .L, .A),

            0x70 => op.ld__WW_rr(cpu, mmu, .HL, .B),
            0x71 => op.ld__WW_rr(cpu, mmu, .HL, .C),
            0x72 => op.ld__WW_rr(cpu, mmu, .HL, .D),
            0x73 => op.ld__WW_rr(cpu, mmu, .HL, .E),
            0x74 => op.ld__WW_rr(cpu, mmu, .HL, .H),
            0x75 => op.ld__WW_rr(cpu, mmu, .HL, .L),
            0x76 => op.sys(cpu, mmu, .halt),
            0x77 => op.ld__WW_rr(cpu, mmu, .HL, .A),
            0x78 => op.ld__rr_rr(cpu, mmu, .A, .B),
            0x79 => op.ld__rr_rr(cpu, mmu, .A, .C),
            0x7A => op.ld__rr_rr(cpu, mmu, .A, .D),
            0x7B => op.ld__rr_rr(cpu, mmu, .A, .E),
            0x7C => op.ld__rr_rr(cpu, mmu, .A, .H),
            0x7D => op.ld__rr_rr(cpu, mmu, .A, .L),
            0x7E => op.ld__rr_WW(cpu, mmu, .A, .HL),
            0x7F => op.ld__rr_rr(cpu, mmu, .A, .A),

            0x80 => op.add_rr_rr(cpu, mmu, .A, .B),
            0x81 => op.add_rr_rr(cpu, mmu, .A, .C),
            0x82 => op.add_rr_rr(cpu, mmu, .A, .D),
            0x83 => op.add_rr_rr(cpu, mmu, .A, .E),
            0x84 => op.add_rr_rr(cpu, mmu, .A, .H),
            0x85 => op.add_rr_rr(cpu, mmu, .A, .L),
            0x86 => op.add_rr_WW(cpu, mmu, .A, .HL),
            0x87 => op.add_rr_rr(cpu, mmu, .A, .A),
            0x88 => op.adc_rr_rr(cpu, mmu, .A, .B),
            0x89 => op.adc_rr_rr(cpu, mmu, .A, .C),
            0x8A => op.adc_rr_rr(cpu, mmu, .A, .D),
            0x8B => op.adc_rr_rr(cpu, mmu, .A, .E),
            0x8C => op.adc_rr_rr(cpu, mmu, .A, .H),
            0x8D => op.adc_rr_rr(cpu, mmu, .A, .L),
            0x8E => op.adc_rr_WW(cpu, mmu, .A, .HL),
            0x8F => op.adc_rr_rr(cpu, mmu, .A, .A),

            0x90 => op.sub_rr_rr(cpu, mmu, .A, .B),
            0x91 => op.sub_rr_rr(cpu, mmu, .A, .C),
            0x92 => op.sub_rr_rr(cpu, mmu, .A, .D),
            0x93 => op.sub_rr_rr(cpu, mmu, .A, .E),
            0x94 => op.sub_rr_rr(cpu, mmu, .A, .H),
            0x95 => op.sub_rr_rr(cpu, mmu, .A, .L),
            0x96 => op.sub_rr_WW(cpu, mmu, .A, .HL),
            0x97 => op.sub_rr_rr(cpu, mmu, .A, .A),
            0x98 => op.sbc_rr_rr(cpu, mmu, .A, .B),
            0x99 => op.sbc_rr_rr(cpu, mmu, .A, .C),
            0x9A => op.sbc_rr_rr(cpu, mmu, .A, .D),
            0x9B => op.sbc_rr_rr(cpu, mmu, .A, .E),
            0x9C => op.sbc_rr_rr(cpu, mmu, .A, .H),
            0x9D => op.sbc_rr_rr(cpu, mmu, .A, .L),
            0x9E => op.sbc_rr_WW(cpu, mmu, .A, .HL),
            0x9F => op.sbc_rr_rr(cpu, mmu, .A, .A),

            0xA0 => op.and_rr_rr(cpu, mmu, .A, .B),
            0xA1 => op.and_rr_rr(cpu, mmu, .A, .C),
            0xA2 => op.and_rr_rr(cpu, mmu, .A, .D),
            0xA3 => op.and_rr_rr(cpu, mmu, .A, .E),
            0xA4 => op.and_rr_rr(cpu, mmu, .A, .H),
            0xA5 => op.and_rr_rr(cpu, mmu, .A, .L),
            0xA6 => op.and_rr_WW(cpu, mmu, .A, .HL),
            0xA7 => op.and_rr_rr(cpu, mmu, .A, .A),
            0xA8 => op.xor_rr_rr(cpu, mmu, .A, .B),
            0xA9 => op.xor_rr_rr(cpu, mmu, .A, .C),
            0xAA => op.xor_rr_rr(cpu, mmu, .A, .D),
            0xAB => op.xor_rr_rr(cpu, mmu, .A, .E),
            0xAC => op.xor_rr_rr(cpu, mmu, .A, .H),
            0xAD => op.xor_rr_rr(cpu, mmu, .A, .L),
            0xAE => op.xor_rr_WW(cpu, mmu, .A, .HL),
            0xAF => op.xor_rr_rr(cpu, mmu, .A, .A),

            0xB0 => op.or__rr_rr(cpu, mmu, .A, .B),
            0xB1 => op.or__rr_rr(cpu, mmu, .A, .C),
            0xB2 => op.or__rr_rr(cpu, mmu, .A, .D),
            0xB3 => op.or__rr_rr(cpu, mmu, .A, .E),
            0xB4 => op.or__rr_rr(cpu, mmu, .A, .H),
            0xB5 => op.or__rr_rr(cpu, mmu, .A, .L),
            0xB6 => op.or__rr_WW(cpu, mmu, .A, .HL),
            0xB7 => op.or__rr_rr(cpu, mmu, .A, .A),
            0xB8 => op.cp__rr_rr(cpu, mmu, .A, .B),
            0xB9 => op.cp__rr_rr(cpu, mmu, .A, .C),
            0xBA => op.cp__rr_rr(cpu, mmu, .A, .D),
            0xBB => op.cp__rr_rr(cpu, mmu, .A, .E),
            0xBC => op.cp__rr_rr(cpu, mmu, .A, .H),
            0xBD => op.cp__rr_rr(cpu, mmu, .A, .L),
            0xBE => op.cp__rr_WW(cpu, mmu, .A, .HL),
            0xBF => op.cp__rr_rr(cpu, mmu, .A, .A),

            0xC0 => op.ret_if___(cpu, mmu, .nz),
            0xC1 => op.pop_ww___(cpu, mmu, .BC),
            0xC2 => op.jp__if_AF(cpu, mmu, .nz, with16(inst)),
            0xC3 => op.jp__AF___(cpu, mmu, with16(inst)),
            0xC4 => op.cal_if_AF(cpu, mmu, .nz, with16(inst)),
            0xC5 => op.psh_ww___(cpu, mmu, .BC),
            0xC6 => op.add_rr_d8(cpu, mmu, .A, with8(inst)),
            0xC7 => op.rst_d8___(cpu, mmu, 0x00),
            0xC8 => op.ret_if___(cpu, mmu, .z),
            0xC9 => op.ret______(cpu, mmu),
            0xCA => op.jp__if_AF(cpu, mmu, .z, with16(inst)),
            0xCB => op.cb(cpu, mmu, inst[1]),
            0xCC => op.cal_if_AF(cpu, mmu, .z, with16(inst)),
            0xCD => op.cal_AF___(cpu, mmu, with16(inst)),
            0xCE => op.adc_rr_d8(cpu, mmu, .A, with8(inst)),
            0xCF => op.rst_d8___(cpu, mmu, 0x08),

            0xD0 => op.ret_if___(cpu, mmu, .nc),
            0xD1 => op.pop_ww___(cpu, mmu, .DE),
            0xD2 => op.jp__if_AF(cpu, mmu, .nc, with16(inst)),
            0xD3 => op.ILLEGAL(cpu, mmu),
            0xD4 => op.cal_if_AF(cpu, mmu, .nc, with16(inst)),
            0xD5 => op.psh_ww___(cpu, mmu, .DE),
            0xD6 => op.sub_rr_d8(cpu, mmu, .A, with8(inst)),
            0xD7 => op.rst_d8___(cpu, mmu, 0x10),
            0xD8 => op.ret_if___(cpu, mmu, .c),
            0xD9 => op.rti______(cpu, mmu),
            0xDA => op.jp__if_AF(cpu, mmu, .c, with16(inst)),
            0xDB => op.ILLEGAL(cpu, mmu),
            0xDC => op.cal_if_AF(cpu, mmu, .c, with16(inst)),
            0xDD => op.ILLEGAL(cpu, mmu),
            0xDE => op.sbc_rr_d8(cpu, mmu, .A, with8(inst)),
            0xDF => op.rst_d8___(cpu, mmu, 0x18),

            0xE0 => op.ldh_A8_rr(cpu, mmu, with8(inst), .A),
            0xE1 => op.pop_ww___(cpu, mmu, .HL),
            0xE2 => op.ld__RR_rr(cpu, mmu, .C, .A),
            0xE3 => op.ILLEGAL(cpu, mmu),
            0xE4 => op.ILLEGAL(cpu, mmu),
            0xE5 => op.psh_ww___(cpu, mmu, .HL),
            0xE6 => op.and_rr_d8(cpu, mmu, .A, with8(inst)),
            0xE7 => op.rst_d8___(cpu, mmu, 0x20),
            0xE8 => op.add_ww_R8(cpu, mmu, .SP, with8(inst)),
            0xE9 => op.jp__WW___(cpu, mmu, .HL),
            0xEA => op.ld__AF_rr(cpu, mmu, with16(inst), .A),
            0xEB => op.ILLEGAL(cpu, mmu),
            0xEC => op.ILLEGAL(cpu, mmu),
            0xED => op.ILLEGAL(cpu, mmu),
            0xEE => op.xor_rr_d8(cpu, mmu, .A, with8(inst)),
            0xEF => op.rst_d8___(cpu, mmu, 0x28),

            0xF0 => op.ldh_rr_A8(cpu, mmu, .A, with8(inst)),
            0xF1 => op.pop_ww___(cpu, mmu, .AF),
            0xF2 => op.ld__rr_RR(cpu, mmu, .A, .C),
            0xF3 => op.int______(cpu, mmu, false),
            0xF4 => op.ILLEGAL(cpu, mmu),
            0xF5 => op.psh_ww___(cpu, mmu, .AF),
            0xF6 => op.or__rr_d8(cpu, mmu, .A, with8(inst)),
            0xF7 => op.rst_d8___(cpu, mmu, 0x30),
            0xF8 => op.ldh_ww_R8(cpu, mmu, .SP, with8(inst)),
            0xF9 => op.ld__ww_ww(cpu, mmu, .SP, .HL),
            0xFA => op.ld__rr_AF(cpu, mmu, .A, with16(inst)),
            0xFB => op.int______(cpu, mmu, true),
            0xFC => op.ILLEGAL(cpu, mmu),
            0xFD => op.ILLEGAL(cpu, mmu),
            0xFE => op.cp__rr_d8(cpu, mmu, .A, with8(inst)),
            0xFF => op.rst_d8___(cpu, mmu, 0x38),
        };
    }
};

fn with8(inst: [*]const u8) u8 {
    return inst[1];
}

fn with16(inst: [*]const u8) u16 {
    return @intCast(u16, inst[2]) << 8 | inst[1];
}
