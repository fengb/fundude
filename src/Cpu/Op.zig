const std = @import("std");
const Cpu = @import("../Cpu.zig");
const util = @import("../util.zig");

pub const impl = @import("impl.zig");

const Reg8 = Cpu.Reg8;
const Reg16 = Cpu.Reg16;
const Flags = Cpu.Flags;

const Op = @This();

id: Id,
length: u8,

arg0: Arg,
arg1: Arg,

durations: [2]u8,

/// Positional argument types:
/// * rb — register byte
/// * rw — register word
/// * ib — immediate byte
/// * iw — immediate word
/// * RB — register byte dereference
/// * RW — register word dereference
/// * IB — immediate byte dereference
/// * IW — immediate word dereference
///
/// * tf — true/false
/// * zc — Z/C flag condition
/// * mo — CPU mode
pub const Id = enum(u8) {
    ILLEGAL___,
    nop_______,
    int__tf___,
    sys__mo___,

    ccf_______,
    scf_______,

    jp___IW___,
    jp___RW___,
    jp___zc_IW,
    jr___IB___,
    jr___zc_IB,
    ret_______,
    reti______,
    ret__zc___,
    call_IW___,
    call_zc_IW,
    rst__ib___,

    ld___IW_rb,
    ld___IW_rw,
    ld___RB_rb,
    ld___RW_ib,
    ld___RW_rb,
    ld___rb_IW,
    ld___rb_RB,
    ld___rb_RW,
    ld___rb_ib,
    ld___rb_rb,
    ld___rw_iw,
    ld___rw_rw,
    ldd__RW_rb,
    ldd__rb_RW,
    ldh__IB_rb,
    ldh__rb_IB,
    ldi__RW_rb,
    ldi__rb_RW,
    ldhl_rw_ib,

    add__rb_RW,
    add__rb_ib,
    add__rb_rb,
    add__rw_ib,
    add__rw_rw,
    sub__rb_RW,
    sub__rb_ib,
    sub__rb_rb,
    adc__rb_RW,
    adc__rb_ib,
    adc__rb_rb,
    sbc__rb_RW,
    sbc__rb_ib,
    sbc__rb_rb,

    and__rb_RW,
    and__rb_ib,
    and__rb_rb,
    or___rb_RW,
    or___rb_ib,
    or___rb_rb,
    xor__rb_RW,
    xor__rb_ib,
    xor__rb_rb,
    cp___rb_RW,
    cp___rb_ib,
    cp___rb_rb,

    cpl__rb___,
    daa__rb___,

    dec__RW___,
    dec__rb___,
    dec__rw___,
    inc__RW___,
    inc__rb___,
    inc__rw___,

    pop__rw___,
    push_rw___,
    rla__rb___,
    rlca_rb___,
    rra__rb___,
    rrca_rb___,

    // -- CB

    rlc__rb___,
    rlc__RW___,
    rrc__rb___,
    rrc__RW___,
    rl___rb___,
    rl___RW___,
    rr___rb___,
    rr___RW___,
    sla__rb___,
    sla__RW___,
    sra__rb___,
    sra__RW___,
    swap_rb___,
    swap_RW___,
    srl__rb___,
    srl__RW___,

    bit__bt_rb,
    bit__bt_RW,
    res__bt_rb,
    res__bt_RW,
    set__bt_rb,
    set__bt_RW,
};

pub const Arg = union {
    __: void,
    ib: u8,
    iw: u16,
    rb: Reg8,
    rw: Reg16,

    bt: u3,
    tf: bool,
    zc: ZC,
    mo: Cpu.Mode,
};

pub const ZC = enum(u16) {
    nz = 0x0_80,
    z = 0x80_80,
    nc = 0x0_10,
    c = 0x10_10,

    pub fn check(self: ZC, cpu: Cpu) bool {
        // return switch (self) {
        //     .nz => !Cpu.reg.flags.Z,
        //     .z => Cpu.reg.flags.Z,
        //     .nc => !Cpu.reg.flags.C,
        //     .c => Cpu.reg.flags.C,
        // };
        const compare = @enumToInt(self) >> 8;
        const mask = 0xff & @enumToInt(self);
        return mask & @bitCast(u8, cpu.reg.flags) == compare;
    }
};

pub fn decode(bytes: [3]u8) Op {
    const ib = bytes[1];
    const iw = @as(u16, bytes[2]) << 8 | bytes[1];
    return switch (bytes[0]) {
        0x00 => Op._____(.nop_______),
        0x01 => Op.rw_iw(.ld___rw_iw, .BC, iw),
        0x02 => Op.rw_rb(.ld___RW_rb, .BC, .A),
        0x03 => Op.rw___(.inc__rw___, .BC),
        0x04 => Op.rb___(.inc__rb___, .B),
        0x05 => Op.rb___(.dec__rb___, .B),
        0x06 => Op.rb_ib(.ld___rb_ib, .B, ib),
        0x07 => Op.rb___(.rlca_rb___, .A),
        0x08 => Op.iw_rw(.ld___IW_rw, iw, .SP),
        0x09 => Op.rw_rw(.add__rw_rw, .HL, .BC),
        0x0A => Op.rb_rw(.ld___rb_RW, .A, .BC),
        0x0B => Op.rw___(.dec__rw___, .BC),
        0x0C => Op.rb___(.inc__rb___, .C),
        0x0D => Op.rb___(.dec__rb___, .C),
        0x0E => Op.rb_ib(.ld___rb_ib, .C, ib),
        0x0F => Op.rb___(.rrca_rb___, .A),

        0x10 => Op.mo___(.sys__mo___, .stop),
        0x11 => Op.rw_iw(.ld___rw_iw, .DE, iw),
        0x12 => Op.rw_rb(.ld___RW_rb, .DE, .A),
        0x13 => Op.rw___(.inc__rw___, .DE),
        0x14 => Op.rb___(.inc__rb___, .D),
        0x15 => Op.rb___(.dec__rb___, .D),
        0x16 => Op.rb_ib(.ld___rb_ib, .D, ib),
        0x17 => Op.rb___(.rla__rb___, .A),
        0x18 => Op.ib___(.jr___IB___, ib),
        0x19 => Op.rw_rw(.add__rw_rw, .HL, .DE),
        0x1A => Op.rb_rw(.ld___rb_RW, .A, .DE),
        0x1B => Op.rw___(.dec__rw___, .DE),
        0x1C => Op.rb___(.inc__rb___, .E),
        0x1D => Op.rb___(.dec__rb___, .E),
        0x1E => Op.rb_ib(.ld___rb_ib, .E, ib),
        0x1F => Op.rb___(.rra__rb___, .A),

        0x20 => Op.zc_ib(.jr___zc_IB, .nz, ib),
        0x21 => Op.rw_iw(.ld___rw_iw, .HL, iw),
        0x22 => Op.rw_rb(.ldi__RW_rb, .HL, .A),
        0x23 => Op.rw___(.inc__rw___, .HL),
        0x24 => Op.rb___(.inc__rb___, .H),
        0x25 => Op.rb___(.dec__rb___, .H),
        0x26 => Op.rb_ib(.ld___rb_ib, .H, ib),
        0x27 => Op.rb___(.daa__rb___, .A),
        0x28 => Op.zc_ib(.jr___zc_IB, .z, ib),
        0x29 => Op.rw_rw(.add__rw_rw, .HL, .HL),
        0x2A => Op.rb_rw(.ldi__rb_RW, .A, .HL),
        0x2B => Op.rw___(.dec__rw___, .HL),
        0x2C => Op.rb___(.inc__rb___, .L),
        0x2D => Op.rb___(.dec__rb___, .L),
        0x2E => Op.rb_ib(.ld___rb_ib, .L, ib),
        0x2F => Op.rb___(.cpl__rb___, .A),

        0x30 => Op.zc_ib(.jr___zc_IB, .nc, ib),
        0x31 => Op.rw_iw(.ld___rw_iw, .SP, iw),
        0x32 => Op.rw_rb(.ldd__RW_rb, .HL, .A),
        0x33 => Op.rw___(.inc__rw___, .SP),
        0x34 => Op.rw___(.inc__RW___, .HL),
        0x35 => Op.rw___(.dec__RW___, .HL),
        0x36 => Op.rw_ib(.ld___RW_ib, .HL, ib),
        0x37 => Op._____(.scf_______),
        0x38 => Op.zc_ib(.jr___zc_IB, .c, ib),
        0x39 => Op.rw_rw(.add__rw_rw, .HL, .SP),
        0x3A => Op.rb_rw(.ldd__rb_RW, .A, .HL),
        0x3B => Op.rw___(.dec__rw___, .SP),
        0x3C => Op.rb___(.inc__rb___, .A),
        0x3D => Op.rb___(.dec__rb___, .A),
        0x3E => Op.rb_ib(.ld___rb_ib, .A, ib),
        0x3F => Op._____(.ccf_______),

        0x40 => Op.rb_rb(.ld___rb_rb, .B, .B),
        0x41 => Op.rb_rb(.ld___rb_rb, .B, .C),
        0x42 => Op.rb_rb(.ld___rb_rb, .B, .D),
        0x43 => Op.rb_rb(.ld___rb_rb, .B, .E),
        0x44 => Op.rb_rb(.ld___rb_rb, .B, .H),
        0x45 => Op.rb_rb(.ld___rb_rb, .B, .L),
        0x46 => Op.rb_rw(.ld___rb_RW, .B, .HL),
        0x47 => Op.rb_rb(.ld___rb_rb, .B, .A),
        0x48 => Op.rb_rb(.ld___rb_rb, .C, .B),
        0x49 => Op.rb_rb(.ld___rb_rb, .C, .C),
        0x4A => Op.rb_rb(.ld___rb_rb, .C, .D),
        0x4B => Op.rb_rb(.ld___rb_rb, .C, .E),
        0x4C => Op.rb_rb(.ld___rb_rb, .C, .H),
        0x4D => Op.rb_rb(.ld___rb_rb, .C, .L),
        0x4E => Op.rb_rw(.ld___rb_RW, .C, .HL),
        0x4F => Op.rb_rb(.ld___rb_rb, .C, .A),

        0x50 => Op.rb_rb(.ld___rb_rb, .D, .B),
        0x51 => Op.rb_rb(.ld___rb_rb, .D, .C),
        0x52 => Op.rb_rb(.ld___rb_rb, .D, .D),
        0x53 => Op.rb_rb(.ld___rb_rb, .D, .E),
        0x54 => Op.rb_rb(.ld___rb_rb, .D, .H),
        0x55 => Op.rb_rb(.ld___rb_rb, .D, .L),
        0x56 => Op.rb_rw(.ld___rb_RW, .D, .HL),
        0x57 => Op.rb_rb(.ld___rb_rb, .D, .A),
        0x58 => Op.rb_rb(.ld___rb_rb, .E, .B),
        0x59 => Op.rb_rb(.ld___rb_rb, .E, .C),
        0x5A => Op.rb_rb(.ld___rb_rb, .E, .D),
        0x5B => Op.rb_rb(.ld___rb_rb, .E, .E),
        0x5C => Op.rb_rb(.ld___rb_rb, .E, .H),
        0x5D => Op.rb_rb(.ld___rb_rb, .E, .L),
        0x5E => Op.rb_rw(.ld___rb_RW, .E, .HL),
        0x5F => Op.rb_rb(.ld___rb_rb, .E, .A),

        0x60 => Op.rb_rb(.ld___rb_rb, .H, .B),
        0x61 => Op.rb_rb(.ld___rb_rb, .H, .C),
        0x62 => Op.rb_rb(.ld___rb_rb, .H, .D),
        0x63 => Op.rb_rb(.ld___rb_rb, .H, .E),
        0x64 => Op.rb_rb(.ld___rb_rb, .H, .H),
        0x65 => Op.rb_rb(.ld___rb_rb, .H, .L),
        0x66 => Op.rb_rw(.ld___rb_RW, .H, .HL),
        0x67 => Op.rb_rb(.ld___rb_rb, .H, .A),
        0x68 => Op.rb_rb(.ld___rb_rb, .L, .B),
        0x69 => Op.rb_rb(.ld___rb_rb, .L, .C),
        0x6A => Op.rb_rb(.ld___rb_rb, .L, .D),
        0x6B => Op.rb_rb(.ld___rb_rb, .L, .E),
        0x6C => Op.rb_rb(.ld___rb_rb, .L, .H),
        0x6D => Op.rb_rb(.ld___rb_rb, .L, .L),
        0x6E => Op.rb_rw(.ld___rb_RW, .L, .HL),
        0x6F => Op.rb_rb(.ld___rb_rb, .L, .A),

        0x70 => Op.rw_rb(.ld___RW_rb, .HL, .B),
        0x71 => Op.rw_rb(.ld___RW_rb, .HL, .C),
        0x72 => Op.rw_rb(.ld___RW_rb, .HL, .D),
        0x73 => Op.rw_rb(.ld___RW_rb, .HL, .E),
        0x74 => Op.rw_rb(.ld___RW_rb, .HL, .H),
        0x75 => Op.rw_rb(.ld___RW_rb, .HL, .L),
        0x76 => Op.mo___(.sys__mo___, .halt),
        0x77 => Op.rw_rb(.ld___RW_rb, .HL, .A),
        0x78 => Op.rb_rb(.ld___rb_rb, .A, .B),
        0x79 => Op.rb_rb(.ld___rb_rb, .A, .C),
        0x7A => Op.rb_rb(.ld___rb_rb, .A, .D),
        0x7B => Op.rb_rb(.ld___rb_rb, .A, .E),
        0x7C => Op.rb_rb(.ld___rb_rb, .A, .H),
        0x7D => Op.rb_rb(.ld___rb_rb, .A, .L),
        0x7E => Op.rb_rw(.ld___rb_RW, .A, .HL),
        0x7F => Op.rb_rb(.ld___rb_rb, .A, .A),

        0x80 => Op.rb_rb(.add__rb_rb, .A, .B),
        0x81 => Op.rb_rb(.add__rb_rb, .A, .C),
        0x82 => Op.rb_rb(.add__rb_rb, .A, .D),
        0x83 => Op.rb_rb(.add__rb_rb, .A, .E),
        0x84 => Op.rb_rb(.add__rb_rb, .A, .H),
        0x85 => Op.rb_rb(.add__rb_rb, .A, .L),
        0x86 => Op.rb_rw(.add__rb_RW, .A, .HL),
        0x87 => Op.rb_rb(.add__rb_rb, .A, .A),
        0x88 => Op.rb_rb(.adc__rb_rb, .A, .B),
        0x89 => Op.rb_rb(.adc__rb_rb, .A, .C),
        0x8A => Op.rb_rb(.adc__rb_rb, .A, .D),
        0x8B => Op.rb_rb(.adc__rb_rb, .A, .E),
        0x8C => Op.rb_rb(.adc__rb_rb, .A, .H),
        0x8D => Op.rb_rb(.adc__rb_rb, .A, .L),
        0x8E => Op.rb_rw(.adc__rb_RW, .A, .HL),
        0x8F => Op.rb_rb(.adc__rb_rb, .A, .A),

        0x90 => Op.rb_rb(.sub__rb_rb, .A, .B),
        0x91 => Op.rb_rb(.sub__rb_rb, .A, .C),
        0x92 => Op.rb_rb(.sub__rb_rb, .A, .D),
        0x93 => Op.rb_rb(.sub__rb_rb, .A, .E),
        0x94 => Op.rb_rb(.sub__rb_rb, .A, .H),
        0x95 => Op.rb_rb(.sub__rb_rb, .A, .L),
        0x96 => Op.rb_rw(.sub__rb_RW, .A, .HL),
        0x97 => Op.rb_rb(.sub__rb_rb, .A, .A),
        0x98 => Op.rb_rb(.sbc__rb_rb, .A, .B),
        0x99 => Op.rb_rb(.sbc__rb_rb, .A, .C),
        0x9A => Op.rb_rb(.sbc__rb_rb, .A, .D),
        0x9B => Op.rb_rb(.sbc__rb_rb, .A, .E),
        0x9C => Op.rb_rb(.sbc__rb_rb, .A, .H),
        0x9D => Op.rb_rb(.sbc__rb_rb, .A, .L),
        0x9E => Op.rb_rw(.sbc__rb_RW, .A, .HL),
        0x9F => Op.rb_rb(.sbc__rb_rb, .A, .A),

        0xA0 => Op.rb_rb(.and__rb_rb, .A, .B),
        0xA1 => Op.rb_rb(.and__rb_rb, .A, .C),
        0xA2 => Op.rb_rb(.and__rb_rb, .A, .D),
        0xA3 => Op.rb_rb(.and__rb_rb, .A, .E),
        0xA4 => Op.rb_rb(.and__rb_rb, .A, .H),
        0xA5 => Op.rb_rb(.and__rb_rb, .A, .L),
        0xA6 => Op.rb_rw(.and__rb_RW, .A, .HL),
        0xA7 => Op.rb_rb(.and__rb_rb, .A, .A),
        0xA8 => Op.rb_rb(.xor__rb_rb, .A, .B),
        0xA9 => Op.rb_rb(.xor__rb_rb, .A, .C),
        0xAA => Op.rb_rb(.xor__rb_rb, .A, .D),
        0xAB => Op.rb_rb(.xor__rb_rb, .A, .E),
        0xAC => Op.rb_rb(.xor__rb_rb, .A, .H),
        0xAD => Op.rb_rb(.xor__rb_rb, .A, .L),
        0xAE => Op.rb_rw(.xor__rb_RW, .A, .HL),
        0xAF => Op.rb_rb(.xor__rb_rb, .A, .A),

        0xB0 => Op.rb_rb(.or___rb_rb, .A, .B),
        0xB1 => Op.rb_rb(.or___rb_rb, .A, .C),
        0xB2 => Op.rb_rb(.or___rb_rb, .A, .D),
        0xB3 => Op.rb_rb(.or___rb_rb, .A, .E),
        0xB4 => Op.rb_rb(.or___rb_rb, .A, .H),
        0xB5 => Op.rb_rb(.or___rb_rb, .A, .L),
        0xB6 => Op.rb_rw(.or___rb_RW, .A, .HL),
        0xB7 => Op.rb_rb(.or___rb_rb, .A, .A),
        0xB8 => Op.rb_rb(.cp___rb_rb, .A, .B),
        0xB9 => Op.rb_rb(.cp___rb_rb, .A, .C),
        0xBA => Op.rb_rb(.cp___rb_rb, .A, .D),
        0xBB => Op.rb_rb(.cp___rb_rb, .A, .E),
        0xBC => Op.rb_rb(.cp___rb_rb, .A, .H),
        0xBD => Op.rb_rb(.cp___rb_rb, .A, .L),
        0xBE => Op.rb_rw(.cp___rb_RW, .A, .HL),
        0xBF => Op.rb_rb(.cp___rb_rb, .A, .A),

        0xC0 => Op.zc___(.ret__zc___, .nz),
        0xC1 => Op.rw___(.pop__rw___, .BC),
        0xC2 => Op.zc_iw(.jp___zc_IW, .nz, iw),
        0xC3 => Op.iw___(.jp___IW___, iw),
        0xC4 => Op.zc_iw(.call_zc_IW, .nz, iw),
        0xC5 => Op.rw___(.push_rw___, .BC),
        0xC6 => Op.rb_ib(.add__rb_ib, .A, ib),
        0xC7 => Op.ib___(.rst__ib___, 0x00),
        0xC8 => Op.zc___(.ret__zc___, .z),
        0xC9 => Op._____(.ret_______),
        0xCA => Op.zc_iw(.jp___zc_IW, .z, iw),
        0xCB => decodeCB(ib),
        0xCC => Op.zc_iw(.call_zc_IW, .z, iw),
        0xCD => Op.iw___(.call_IW___, iw),
        0xCE => Op.rb_ib(.adc__rb_ib, .A, ib),
        0xCF => Op.ib___(.rst__ib___, 0x08),

        0xD0 => Op.zc___(.ret__zc___, .nc),
        0xD1 => Op.rw___(.pop__rw___, .DE),
        0xD2 => Op.zc_iw(.jp___zc_IW, .nc, iw),
        0xD3 => Op._____(.ILLEGAL___),
        0xD4 => Op.zc_iw(.call_zc_IW, .nc, iw),
        0xD5 => Op.rw___(.push_rw___, .DE),
        0xD6 => Op.rb_ib(.sub__rb_ib, .A, ib),
        0xD7 => Op.ib___(.rst__ib___, 0x10),
        0xD8 => Op.zc___(.ret__zc___, .c),
        0xD9 => Op._____(.reti______),
        0xDA => Op.zc_iw(.jp___zc_IW, .c, iw),
        0xDB => Op._____(.ILLEGAL___),
        0xDC => Op.zc_iw(.call_zc_IW, .c, iw),
        0xDD => Op._____(.ILLEGAL___),
        0xDE => Op.rb_ib(.sbc__rb_ib, .A, ib),
        0xDF => Op.ib___(.rst__ib___, 0x18),

        0xE0 => Op.ib_rb(.ldh__IB_rb, ib, .A),
        0xE1 => Op.rw___(.pop__rw___, .HL),
        0xE2 => Op.rb_rb(.ld___RB_rb, .C, .A),
        0xE3 => Op._____(.ILLEGAL___),
        0xE4 => Op._____(.ILLEGAL___),
        0xE5 => Op.rw___(.push_rw___, .HL),
        0xE6 => Op.rb_ib(.and__rb_ib, .A, ib),
        0xE7 => Op.ib___(.rst__ib___, 0x20),
        0xE8 => Op.rw_ib(.add__rw_ib, .SP, ib),
        0xE9 => Op.rw___(.jp___RW___, .HL),
        0xEA => Op.iw_rb(.ld___IW_rb, iw, .A),
        0xEB => Op._____(.ILLEGAL___),
        0xEC => Op._____(.ILLEGAL___),
        0xED => Op._____(.ILLEGAL___),
        0xEE => Op.rb_ib(.xor__rb_ib, .A, ib),
        0xEF => Op.ib___(.rst__ib___, 0x28),

        0xF0 => Op.rb_ib(.ldh__rb_IB, .A, ib),
        0xF1 => Op.rw___(.pop__rw___, .AF),
        0xF2 => Op.rb_rb(.ld___rb_RB, .A, .C),
        0xF3 => Op.tf___(.int__tf___, false),
        0xF4 => Op._____(.ILLEGAL___),
        0xF5 => Op.rw___(.push_rw___, .AF),
        0xF6 => Op.rb_ib(.or___rb_ib, .A, ib),
        0xF7 => Op.ib___(.rst__ib___, 0x30),
        0xF8 => Op.rw_ib(.ldhl_rw_ib, .SP, ib),
        0xF9 => Op.rw_rw(.ld___rw_rw, .SP, .HL),
        0xFA => Op.rb_iw(.ld___rb_IW, .A, iw),
        0xFB => Op.tf___(.int__tf___, true),
        0xFC => Op._____(.ILLEGAL___),
        0xFD => Op._____(.ILLEGAL___),
        0xFE => Op.rb_ib(.cp___rb_ib, .A, ib),
        0xFF => Op.ib___(.rst__ib___, 0x38),
    };
}

pub fn decodeCB(next: u8) Op {
    const suffix = @truncate(u3, next);
    const prefix = next - suffix;
    const bit = @truncate(u3, next >> 3);

    const reg: Reg8 = switch (suffix) {
        0x0 => .B,
        0x1 => .C,
        0x2 => .D,
        0x3 => .E,
        0x4 => .H,
        0x5 => .L,
        0x6 => {
            return switch (prefix) {
                0x00...0x07 => Op.rw___(.rlc__RW___, .HL),
                0x08...0x0F => Op.rw___(.rrc__RW___, .HL),
                0x10...0x17 => Op.rw___(.rl___RW___, .HL),
                0x18...0x1F => Op.rw___(.rr___RW___, .HL),
                0x20...0x27 => Op.rw___(.sla__RW___, .HL),
                0x28...0x2F => Op.rw___(.sra__RW___, .HL),
                0x30...0x37 => Op.rw___(.swap_RW___, .HL),
                0x38...0x3F => Op.rw___(.srl__RW___, .HL),

                0x40...0x7F => Op.bt_rw(.bit__bt_RW, bit, .HL),
                0x80...0xBF => Op.bt_rw(.res__bt_RW, bit, .HL),
                0xC0...0xFF => Op.bt_rw(.set__bt_RW, bit, .HL),
            };
        },
        0x7 => .A,
    };

    return switch (prefix) {
        0x00...0x07 => Op.rb___(.rlc__rb___, reg),
        0x08...0x0F => Op.rb___(.rrc__rb___, reg),
        0x10...0x17 => Op.rb___(.rl___rb___, reg),
        0x18...0x1F => Op.rb___(.rr___rb___, reg),
        0x20...0x27 => Op.rb___(.sla__rb___, reg),
        0x28...0x2F => Op.rb___(.sra__rb___, reg),
        0x30...0x37 => Op.rb___(.swap_rb___, reg),
        0x38...0x3F => Op.rb___(.srl__rb___, reg),

        0x40...0x7F => Op.bt_rb(.bit__bt_rb, bit, reg),
        0x80...0xBF => Op.bt_rb(.res__bt_rb, bit, reg),
        0xC0...0xFF => Op.bt_rb(.set__bt_rb, bit, reg),
    };
}

test "decode sanity" {
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const bytes = [_]u8{ @truncate(u8, i), 0, 0 };
        const op = decode(bytes);
        try std.testing.expect(op.length > 0);

        try std.testing.expect(op.durations[0] > 0);
        try std.testing.expect(op.durations[1] > 0);
        try std.testing.expect(op.durations[0] <= op.durations[1]);

        try std.testing.expect(op.durations[0] % 4 == 0);
        try std.testing.expect(op.durations[1] % 4 == 0);
    }
}

pub fn disassemble(op: Op, buffer: []u8) ![]u8 {
    var stream = std.io.fixedBufferStream(buffer);
    const os = stream.writer();

    if (@call(.{ .modifier = .never_inline }, disassembleSpecial, .{op})) |special| {
        std.mem.copy(u8, buffer[0..16], special);
        return buffer[0..special.len];
    }

    const enum_name = @tagName(op.id);
    for (enum_name) |letter| {
        if (letter == '_') break;
        _ = try os.write(&[1]u8{letter});
    }

    try disassembleArg(os, enum_name[5..7], op.arg0);
    try disassembleArg(os, enum_name[8..10], op.arg1);

    return util.makeUpper(stream.getWritten());
}

fn disassembleSpecial(op: Op) ?[]const u8 {
    return switch (op.id) {
        .ILLEGAL___ => "",
        .sys__mo___ => switch (op.arg0.mo) {
            .halt => "HALT",
            .stop => "STOP",
            else => unreachable,
        },
        .int__tf___ => switch (op.arg0.tf) {
            true => "EI",
            false => "DI",
        },
        else => null,
    };
}

fn disassembleArg(writer: anytype, name: *const [2]u8, arg: Op.Arg) !void {
    if (std.mem.eql(u8, "__", name)) return;

    _ = try writer.write(" ");

    if (std.ascii.isUpper(name[0])) {
        _ = try writer.write("(");
    }
    const swh = util.Swhash(2);
    switch (swh.match(name)) {
        swh.case("zc") => _ = try writer.write(@tagName(arg.zc)),
        swh.case("bt") => _ = try writer.write(&[1]u8{'0' + @as(u8, arg.bt)}),
        swh.case("ib"), swh.case("IB") => try printHexes(writer, 2, arg.ib),
        swh.case("iw"), swh.case("IW") => try printHexes(writer, 4, arg.iw),
        swh.case("rb"), swh.case("RB") => _ = try writer.write(@tagName(arg.rb)),
        swh.case("rw"), swh.case("RW") => _ = try writer.write(@tagName(arg.rw)),
        else => unreachable,
    }

    if (std.ascii.isUpper(name[0])) {
        _ = try writer.write(")");
    }
}

fn printHexes(writer: anytype, length: u3, val: u16) !void {
    @setCold(true);
    _ = try writer.write("$");
    var i: u4 = length;
    while (i > 0) {
        i -= 1;
        const digit_num: u8 = @truncate(u4, val >> (4 * i));
        _ = try writer.write(&[1]u8{
            if (digit_num < 10) '0' + digit_num else 'A' + digit_num - 10,
        });
    }
}

// -- init helpers

fn init(comptime id: Id, arg0: Arg, arg1: Arg) Op {
    const func = @field(Op.impl, @tagName(id));
    const ResultMeta = @typeInfo(@TypeOf(func)).Fn.return_type.?;

    return .{
        .id = id,
        .arg0 = arg0,
        .arg1 = arg1,

        .length = ResultMeta.length,
        .durations = ResultMeta.durations,
    };
}

pub fn _____(comptime id: Id) Op {
    return init(id, .{ .__ = {} }, .{ .__ = {} });
}

pub fn tf___(comptime id: Id, arg0: bool) Op {
    return init(id, .{ .tf = arg0 }, .{ .__ = {} });
}

pub fn mo___(comptime id: Id, arg0: Cpu.Mode) Op {
    return init(id, .{ .mo = arg0 }, .{ .__ = {} });
}

pub fn ib___(comptime id: Id, arg0: u8) Op {
    return init(id, .{ .ib = arg0 }, .{ .__ = {} });
}

pub fn iw___(comptime id: Id, arg0: u16) Op {
    return init(id, .{ .iw = arg0 }, .{ .__ = {} });
}

pub fn rb___(comptime id: Id, arg0: Reg8) Op {
    return init(id, .{ .rb = arg0 }, .{ .__ = {} });
}

pub fn rw___(comptime id: Id, arg0: Reg16) Op {
    return init(id, .{ .rw = arg0 }, .{ .__ = {} });
}

pub fn zc___(comptime id: Id, arg0: ZC) Op {
    return init(id, .{ .zc = arg0 }, .{ .__ = {} });
}

pub fn zc_ib(comptime id: Id, arg0: ZC, arg1: u8) Op {
    return init(id, .{ .zc = arg0 }, .{ .ib = arg1 });
}

pub fn zc_iw(comptime id: Id, arg0: ZC, arg1: u16) Op {
    return init(id, .{ .zc = arg0 }, .{ .iw = arg1 });
}

pub fn ib_rb(comptime id: Id, arg0: u8, arg1: Reg8) Op {
    return init(id, .{ .ib = arg0 }, .{ .rb = arg1 });
}

pub fn iw_ib(comptime id: Id, arg0: u16, arg1: u8) Op {
    return init(id, .{ .iw = arg0 }, .{ .ib = arg1 });
}

pub fn iw_rb(comptime id: Id, arg0: u16, arg1: Reg8) Op {
    return init(id, .{ .iw = arg0 }, .{ .rb = arg1 });
}

pub fn iw_rw(comptime id: Id, arg0: u16, arg1: Reg16) Op {
    return init(id, .{ .iw = arg0 }, .{ .rw = arg1 });
}

pub fn rb_ib(comptime id: Id, arg0: Reg8, arg1: u8) Op {
    return init(id, .{ .rb = arg0 }, .{ .ib = arg1 });
}

pub fn rb_iw(comptime id: Id, arg0: Reg8, arg1: u16) Op {
    return init(id, .{ .rb = arg0 }, .{ .iw = arg1 });
}

pub fn rb_rb(comptime id: Id, arg0: Reg8, arg1: Reg8) Op {
    return init(id, .{ .rb = arg0 }, .{ .rb = arg1 });
}

pub fn rb_rw(comptime id: Id, arg0: Reg8, arg1: Reg16) Op {
    return init(id, .{ .rb = arg0 }, .{ .rw = arg1 });
}

pub fn rw_ib(comptime id: Id, arg0: Reg16, arg1: u8) Op {
    return init(id, .{ .rw = arg0 }, .{ .ib = arg1 });
}

pub fn rw_iw(comptime id: Id, arg0: Reg16, arg1: u16) Op {
    return init(id, .{ .rw = arg0 }, .{ .iw = arg1 });
}

pub fn rw_rb(comptime id: Id, arg0: Reg16, arg1: Reg8) Op {
    return init(id, .{ .rw = arg0 }, .{ .rb = arg1 });
}

pub fn rw_rw(comptime id: Id, arg0: Reg16, arg1: Reg16) Op {
    return init(id, .{ .rw = arg0 }, .{ .rw = arg1 });
}

pub fn bt_rb(comptime id: Id, arg0: u3, arg1: Reg8) Op {
    return init(id, .{ .bt = arg0 }, .{ .rb = arg1 });
}

pub fn bt_rw(comptime id: Id, arg0: u3, arg1: Reg16) Op {
    return init(id, .{ .bt = arg0 }, .{ .rw = arg1 });
}
