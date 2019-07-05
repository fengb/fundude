const base = @import("base.zig");
const op = @import("cpu_op.zig");
const irq = @import("irq.zig");

pub const Result = op.Result;

pub const Mode = enum {
    norm,
    halt,
    stop,
    illegal,
    fatal, // Not a GB mode, this code is bad and we should feel bad
};

pub const Reg8 = packed struct {
    _: u8,
};

pub const Reg16 = packed union {
    _: u16,
    x: struct {
        _1: Reg8,
        _0: Reg8,
    },
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
        _16: packed struct {
            AF: Reg16,
            BC: Reg16,
            DE: Reg16,
            HL: Reg16,
            SP: Reg16,
            PC: Reg16,
        },

        flags: Flags,
    },

    pub fn reset(self: *Cpu) void {
        self.mode = .norm;
        self.interrupt_master = false;
        self.reg._16.PC._ = 0;
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
            return self.opStep(mmu, mmu.ptr(self.reg._16.PC._));
        }
    }

    fn irqStep(self: *Cpu, mmu: *base.Mmu) ?Result {
        if (!self.interrupt_master) {
            return null;
        }

        const OP_CALL = 0xCD;
        const cmp = mmu.io.IF.cmp(mmu.interrupt_enable);
        const addr = switch (cmp.active() orelse return null) {
            .vblank => blk: {
                mmu.io.IF.vblank = false;
                break :blk u8(0x40);
            },
            .lcd_stat => blk: {
                mmu.io.IF.vblank = false;
                break :blk u8(0x40);
            },
            .timer => blk: {
                mmu.io.IF.vblank = false;
                break :blk u8(0x40);
            },
            .serial => blk: {
                mmu.io.IF.vblank = false;
                break :blk u8(0x40);
            },
            .joypad => blk: {
                mmu.io.IF.vblank = false;
                break :blk u8(0x40);
            },
        };

        self.mode = .norm;
        self.interrupt_master = false;
        // TODO: this is silly -- we reverse the hacked offset in OP CALL
        self.reg._16.PC._ -= 3;

        const inst = [_]u8{ OP_CALL, addr, 0 };
        return self.opStep(mmu, &inst);
    }

    fn opStep(cpu: *Cpu, mmu: *base.Mmu, inst: [*]u8) Result {
        return switch (inst[0]) {
            0x00 => op.nop(cpu, mmu),
            0x01 => op.ld__ww_df(cpu, mmu, &cpu.reg._16.BC, with16(inst)),
            0x02 => op.ld__WW_rr(cpu, mmu, &cpu.reg._16.BC, &cpu.reg._16.AF.x._0),
            0x03 => op.inc_ww___(cpu, mmu, &cpu.reg._16.BC),
            0x04 => op.inc_rr___(cpu, mmu, &cpu.reg._16.BC.x._0),
            0x05 => op.dec_rr___(cpu, mmu, &cpu.reg._16.BC.x._0),
            0x06 => op.ld__rr_d8(cpu, mmu, &cpu.reg._16.BC.x._0, with8(inst)),
            0x07 => op.rlc_rr___(cpu, mmu, &cpu.reg._16.AF.x._0),
            0x08 => op.ld__AF_ww(cpu, mmu, with16(inst), &cpu.reg._16.SP),
            0x09 => op.add_ww_ww(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.BC),
            0x0A => op.ld__rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC),
            0x0B => op.dec_ww___(cpu, mmu, &cpu.reg._16.BC),
            0x0C => op.inc_rr___(cpu, mmu, &cpu.reg._16.BC.x._1),
            0x0D => op.dec_rr___(cpu, mmu, &cpu.reg._16.BC.x._1),
            0x0E => op.ld__rr_d8(cpu, mmu, &cpu.reg._16.BC.x._1, with8(inst)),
            0x0F => op.rrc_rr___(cpu, mmu, &cpu.reg._16.AF.x._0),

            0x10 => op.sys(cpu, mmu, .stop),
            0x11 => op.ld__ww_df(cpu, mmu, &cpu.reg._16.DE, with16(inst)),
            0x12 => op.ld__WW_rr(cpu, mmu, &cpu.reg._16.DE, &cpu.reg._16.AF.x._0),
            0x13 => op.inc_ww___(cpu, mmu, &cpu.reg._16.DE),
            0x14 => op.inc_rr___(cpu, mmu, &cpu.reg._16.DE.x._0),
            0x15 => op.dec_rr___(cpu, mmu, &cpu.reg._16.DE.x._0),
            0x16 => op.ld__rr_d8(cpu, mmu, &cpu.reg._16.DE.x._0, with8(inst)),
            0x17 => op.rla_rr___(cpu, mmu, &cpu.reg._16.AF.x._0),
            0x18 => op.jr__R8___(cpu, mmu, with8(inst)),
            0x19 => op.add_ww_ww(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.DE),
            0x1A => op.ld__rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE),
            0x1B => op.dec_ww___(cpu, mmu, &cpu.reg._16.DE),
            0x1C => op.inc_rr___(cpu, mmu, &cpu.reg._16.DE.x._1),
            0x1D => op.dec_rr___(cpu, mmu, &cpu.reg._16.DE.x._1),
            0x1E => op.ld__rr_d8(cpu, mmu, &cpu.reg._16.DE.x._1, with8(inst)),
            0x1F => op.rra_rr___(cpu, mmu, &cpu.reg._16.AF.x._0),

            0x20 => op.jr__if_R8(cpu, mmu, .nz, with8(inst)),
            0x21 => op.ld__ww_df(cpu, mmu, &cpu.reg._16.HL, with16(inst)),
            0x22 => op.ldi_WW_rr(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.AF.x._0),
            0x23 => op.inc_ww___(cpu, mmu, &cpu.reg._16.HL),
            0x24 => op.inc_rr___(cpu, mmu, &cpu.reg._16.HL.x._0),
            0x25 => op.dec_rr___(cpu, mmu, &cpu.reg._16.HL.x._0),
            0x26 => op.ld__rr_d8(cpu, mmu, &cpu.reg._16.HL.x._0, with8(inst)),
            0x27 => op.daa_rr___(cpu, mmu, &cpu.reg._16.AF.x._0),
            0x28 => op.jr__if_R8(cpu, mmu, .z, with8(inst)),
            0x29 => op.add_ww_ww(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.HL),
            0x2A => op.ldi_rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0x2B => op.dec_ww___(cpu, mmu, &cpu.reg._16.HL),
            0x2C => op.inc_rr___(cpu, mmu, &cpu.reg._16.HL.x._1),
            0x2D => op.dec_rr___(cpu, mmu, &cpu.reg._16.HL.x._1),
            0x2E => op.ld__rr_d8(cpu, mmu, &cpu.reg._16.HL.x._1, with8(inst)),
            0x2F => op.cpl_rr___(cpu, mmu, &cpu.reg._16.AF.x._0),

            0x30 => op.jr__if_R8(cpu, mmu, .nc, with8(inst)),
            0x31 => op.ld__ww_df(cpu, mmu, &cpu.reg._16.SP, with16(inst)),
            0x32 => op.ldd_WW_rr(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.AF.x._0),
            0x33 => op.inc_ww___(cpu, mmu, &cpu.reg._16.SP),
            0x34 => op.inc_WW___(cpu, mmu, &cpu.reg._16.HL),
            0x35 => op.dec_WW___(cpu, mmu, &cpu.reg._16.HL),
            0x36 => op.ld__WW_d8(cpu, mmu, &cpu.reg._16.HL, with8(inst)),
            0x37 => op.scf(cpu, mmu),
            0x38 => op.jr__if_R8(cpu, mmu, .c, with8(inst)),
            0x39 => op.add_ww_ww(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.SP),
            0x3A => op.ldd_rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0x3B => op.dec_ww___(cpu, mmu, &cpu.reg._16.SP),
            0x3C => op.inc_rr___(cpu, mmu, &cpu.reg._16.AF.x._0),
            0x3D => op.dec_rr___(cpu, mmu, &cpu.reg._16.AF.x._0),
            0x3E => op.ld__rr_d8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0x3F => op.ccf(cpu, mmu),

            0x40 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._0, &cpu.reg._16.BC.x._0),
            0x41 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._0, &cpu.reg._16.BC.x._1),
            0x42 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._0, &cpu.reg._16.DE.x._0),
            0x43 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._0, &cpu.reg._16.DE.x._1),
            0x44 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._0, &cpu.reg._16.HL.x._0),
            0x45 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._0, &cpu.reg._16.HL.x._1),
            0x46 => op.ld__rr_WW(cpu, mmu, &cpu.reg._16.BC.x._0, &cpu.reg._16.HL),
            0x47 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._0, &cpu.reg._16.AF.x._0),
            0x48 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._1, &cpu.reg._16.BC.x._0),
            0x49 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._1, &cpu.reg._16.BC.x._1),
            0x4A => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._1, &cpu.reg._16.DE.x._0),
            0x4B => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._1, &cpu.reg._16.DE.x._1),
            0x4C => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._1, &cpu.reg._16.HL.x._0),
            0x4D => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._1, &cpu.reg._16.HL.x._1),
            0x4E => op.ld__rr_WW(cpu, mmu, &cpu.reg._16.BC.x._1, &cpu.reg._16.HL),
            0x4F => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.BC.x._1, &cpu.reg._16.AF.x._0),

            0x50 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._0, &cpu.reg._16.BC.x._0),
            0x51 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._0, &cpu.reg._16.BC.x._1),
            0x52 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._0, &cpu.reg._16.DE.x._0),
            0x53 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._0, &cpu.reg._16.DE.x._1),
            0x54 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._0, &cpu.reg._16.HL.x._0),
            0x55 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._0, &cpu.reg._16.HL.x._1),
            0x56 => op.ld__rr_WW(cpu, mmu, &cpu.reg._16.DE.x._0, &cpu.reg._16.HL),
            0x57 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._0, &cpu.reg._16.AF.x._0),
            0x58 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._1, &cpu.reg._16.BC.x._0),
            0x59 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._1, &cpu.reg._16.BC.x._1),
            0x5A => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._1, &cpu.reg._16.DE.x._0),
            0x5B => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._1, &cpu.reg._16.DE.x._1),
            0x5C => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._1, &cpu.reg._16.HL.x._0),
            0x5D => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._1, &cpu.reg._16.HL.x._1),
            0x5E => op.ld__rr_WW(cpu, mmu, &cpu.reg._16.DE.x._1, &cpu.reg._16.HL),
            0x5F => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.DE.x._1, &cpu.reg._16.AF.x._0),

            0x60 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._0, &cpu.reg._16.BC.x._0),
            0x61 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._0, &cpu.reg._16.BC.x._1),
            0x62 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._0, &cpu.reg._16.DE.x._0),
            0x63 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._0, &cpu.reg._16.DE.x._1),
            0x64 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._0, &cpu.reg._16.HL.x._0),
            0x65 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._0, &cpu.reg._16.HL.x._1),
            0x66 => op.ld__rr_WW(cpu, mmu, &cpu.reg._16.HL.x._0, &cpu.reg._16.HL),
            0x67 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._0, &cpu.reg._16.AF.x._0),
            0x68 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._1, &cpu.reg._16.BC.x._0),
            0x69 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._1, &cpu.reg._16.BC.x._1),
            0x6A => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._1, &cpu.reg._16.DE.x._0),
            0x6B => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._1, &cpu.reg._16.DE.x._1),
            0x6C => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._1, &cpu.reg._16.HL.x._0),
            0x6D => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._1, &cpu.reg._16.HL.x._1),
            0x6E => op.ld__rr_WW(cpu, mmu, &cpu.reg._16.HL.x._1, &cpu.reg._16.HL),
            0x6F => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.HL.x._1, &cpu.reg._16.AF.x._0),

            0x70 => op.ld__WW_rr(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.BC.x._0),
            0x71 => op.ld__WW_rr(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.BC.x._1),
            0x72 => op.ld__WW_rr(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.DE.x._0),
            0x73 => op.ld__WW_rr(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.DE.x._1),
            0x74 => op.ld__WW_rr(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.HL.x._0),
            0x75 => op.ld__WW_rr(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.HL.x._1),
            0x76 => op.sys(cpu, mmu, .halt),
            0x77 => op.ld__WW_rr(cpu, mmu, &cpu.reg._16.HL, &cpu.reg._16.AF.x._0),
            0x78 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._0),
            0x79 => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0x7A => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._0),
            0x7B => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._1),
            0x7C => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._0),
            0x7D => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._1),
            0x7E => op.ld__rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0x7F => op.ld__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.AF.x._0),

            0x80 => op.add_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._0),
            0x81 => op.add_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0x82 => op.add_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._0),
            0x83 => op.add_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._1),
            0x84 => op.add_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._0),
            0x85 => op.add_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._1),
            0x86 => op.add_rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0x87 => op.add_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.AF.x._0),
            0x88 => op.adc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._0),
            0x89 => op.adc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0x8A => op.adc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._0),
            0x8B => op.adc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._1),
            0x8C => op.adc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._0),
            0x8D => op.adc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._1),
            0x8E => op.adc_rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0x8F => op.adc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.AF.x._0),

            0x90 => op.sub_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._0),
            0x91 => op.sub_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0x92 => op.sub_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._0),
            0x93 => op.sub_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._1),
            0x94 => op.sub_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._0),
            0x95 => op.sub_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._1),
            0x96 => op.sub_rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0x97 => op.sub_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.AF.x._0),
            0x98 => op.sbc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._0),
            0x99 => op.sbc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0x9A => op.sbc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._0),
            0x9B => op.sbc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._1),
            0x9C => op.sbc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._0),
            0x9D => op.sbc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._1),
            0x9E => op.sbc_rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0x9F => op.sbc_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.AF.x._0),

            0xA0 => op.and_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._0),
            0xA1 => op.and_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0xA2 => op.and_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._0),
            0xA3 => op.and_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._1),
            0xA4 => op.and_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._0),
            0xA5 => op.and_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._1),
            0xA6 => op.and_rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0xA7 => op.and_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.AF.x._0),
            0xA8 => op.xor_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._0),
            0xA9 => op.xor_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0xAA => op.xor_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._0),
            0xAB => op.xor_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._1),
            0xAC => op.xor_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._0),
            0xAD => op.xor_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._1),
            0xAE => op.xor_rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0xAF => op.xor_rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.AF.x._0),

            0xB0 => op.or__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._0),
            0xB1 => op.or__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0xB2 => op.or__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._0),
            0xB3 => op.or__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._1),
            0xB4 => op.or__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._0),
            0xB5 => op.or__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._1),
            0xB6 => op.or__rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0xB7 => op.or__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.AF.x._0),
            0xB8 => op.cp__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._0),
            0xB9 => op.cp__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0xBA => op.cp__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._0),
            0xBB => op.cp__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.DE.x._1),
            0xBC => op.cp__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._0),
            0xBD => op.cp__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL.x._1),
            0xBE => op.cp__rr_WW(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.HL),
            0xBF => op.cp__rr_rr(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.AF.x._0),

            0xC0 => op.ret_if___(cpu, mmu, .nz),
            0xC1 => op.pop_ww___(cpu, mmu, &cpu.reg._16.BC),
            0xC2 => op.jp__if_AF(cpu, mmu, .nz, with16(inst)),
            0xC3 => op.jp__AF___(cpu, mmu, with16(inst)),
            0xC4 => op.cal_if_AF(cpu, mmu, .nz, with16(inst)),
            0xC5 => op.psh_ww___(cpu, mmu, &cpu.reg._16.BC),
            0xC6 => op.add_rr_d8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0xC7 => op.rst_d8___(cpu, mmu, 0x00),
            0xC8 => op.ret_if___(cpu, mmu, .z),
            0xC9 => op.ret______(cpu, mmu),
            0xCA => op.jp__if_AF(cpu, mmu, .z, with16(inst)),
            0xCB => op.cb(cpu, mmu, inst[1]),
            0xCC => op.cal_if_AF(cpu, mmu, .z, with16(inst)),
            0xCD => op.cal_AF___(cpu, mmu, with16(inst)),
            0xCE => op.adc_rr_d8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0xCF => op.rst_d8___(cpu, mmu, 0x08),

            0xD0 => op.ret_if___(cpu, mmu, .nc),
            0xD1 => op.pop_ww___(cpu, mmu, &cpu.reg._16.DE),
            0xD2 => op.jp__if_AF(cpu, mmu, .nc, with16(inst)),
            0xD3 => op.ILLEGAL(cpu, mmu),
            0xD4 => op.cal_if_AF(cpu, mmu, .nc, with16(inst)),
            0xD5 => op.psh_ww___(cpu, mmu, &cpu.reg._16.DE),
            0xD6 => op.sub_rr_d8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0xD7 => op.rst_d8___(cpu, mmu, 0x10),
            0xD8 => op.ret_if___(cpu, mmu, .c),
            0xD9 => op.rti______(cpu, mmu),
            0xDA => op.jp__if_AF(cpu, mmu, .c, with16(inst)),
            0xDB => op.ILLEGAL(cpu, mmu),
            0xDC => op.cal_if_AF(cpu, mmu, .c, with16(inst)),
            0xDD => op.ILLEGAL(cpu, mmu),
            0xDE => op.sbc_rr_d8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0xDF => op.rst_d8___(cpu, mmu, 0x18),

            0xE0 => op.ldh_A8_rr(cpu, mmu, with8(inst), &cpu.reg._16.AF.x._0),
            0xE1 => op.pop_ww___(cpu, mmu, &cpu.reg._16.HL),
            0xE2 => op.ld__RR_rr(cpu, mmu, &cpu.reg._16.BC.x._1, &cpu.reg._16.AF.x._0),
            0xE3 => op.ILLEGAL(cpu, mmu),
            0xE4 => op.ILLEGAL(cpu, mmu),
            0xE5 => op.psh_ww___(cpu, mmu, &cpu.reg._16.HL),
            0xE6 => op.and_rr_d8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0xE7 => op.rst_d8___(cpu, mmu, 0x20),
            0xE8 => op.add_ww_R8(cpu, mmu, &cpu.reg._16.SP, with8(inst)),
            0xE9 => op.jp__WW___(cpu, mmu, &cpu.reg._16.HL),
            0xEA => op.ld__AF_rr(cpu, mmu, with16(inst), &cpu.reg._16.AF.x._0),
            0xEB => op.ILLEGAL(cpu, mmu),
            0xEC => op.ILLEGAL(cpu, mmu),
            0xED => op.ILLEGAL(cpu, mmu),
            0xEE => op.xor_rr_d8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0xEF => op.rst_d8___(cpu, mmu, 0x28),

            0xF0 => op.ldh_rr_A8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0xF1 => op.pop_ww___(cpu, mmu, &cpu.reg._16.AF),
            0xF2 => op.ld__rr_RR(cpu, mmu, &cpu.reg._16.AF.x._0, &cpu.reg._16.BC.x._1),
            0xF3 => op.int______(cpu, mmu, false),
            0xF4 => op.ILLEGAL(cpu, mmu),
            0xF5 => op.psh_ww___(cpu, mmu, &cpu.reg._16.AF),
            0xF6 => op.or__rr_d8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0xF7 => op.rst_d8___(cpu, mmu, 0x30),
            0xF8 => op.ldh_ww_R8(cpu, mmu, &cpu.reg._16.SP, with8(inst)),
            0xF9 => op.ld__ww_ww(cpu, mmu, &cpu.reg._16.SP, &cpu.reg._16.HL),
            0xFA => op.ld__rr_AF(cpu, mmu, &cpu.reg._16.AF.x._0, with16(inst)),
            0xFB => op.int______(cpu, mmu, true),
            0xFC => op.ILLEGAL(cpu, mmu),
            0xFD => op.ILLEGAL(cpu, mmu),
            0xFE => op.cp__rr_d8(cpu, mmu, &cpu.reg._16.AF.x._0, with8(inst)),
            0xFF => op.rst_d8___(cpu, mmu, 0x38),
        };
    }
};

fn with8(inst: [*]u8) u8 {
    return inst[1];
}

fn with16(inst: [*]u8) u16 {
    return @intCast(u16, inst[2]) << 8 | inst[1];
}
