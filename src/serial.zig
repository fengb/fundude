const std = @import("std");

const Fundude = @import("main.zig");

pub const Io = packed struct {
    SB: u8, // $FF01
    SC: packed struct { // $FF02
        shift_clock: enum(u1) { External, Internal },
        clock_speed: enum(u1) { Normal, Fast },
        _pad: u5,
        transfer_start_flag: bool,
    },
};

const master_cycles = 512;

pub const Serial = struct {
    guest_sb: ?*u8,
    guest_if: ?*Fundude.Cpu.Irq,

    current_bit: u3,

    pub fn reset(self: *Serial) void {
        self.disconnect();
        self.current_bit = 0;
    }

    fn getBit(val: u8, pos: u3) u8 {
        return val >> pos & 1;
    }

    pub fn connect(self: *Serial, target_mmio: *Fundude.Mmu.Io) void {
        self.guest_sb = &target_mmio.serial.SB;
        self.guest_if = &target_mmio.IF;
    }

    pub fn disconnect(self: *Serial) void {
        self.guest_sb = null;
        self.guest_if = null;
    }

    pub fn shift(self: *Serial, mmu: *Fundude.Mmu) void {
        if (self.guest_sb) |guest_sb| {
            const host_msb = getBit(mmu.dyn.io.serial.SB, 7);
            const guest_msb = getBit(guest_sb.*, 7);

            mmu.dyn.io.serial.SB = (mmu.dyn.io.serial.SB << 1) | guest_msb;
            guest_sb.* = (guest_sb.* << 1) | host_msb;
        } else {
            mmu.dyn.io.serial.SB <<= 1;
        }

        if (@addWithOverflow(u3, self.current_bit, 1, &self.current_bit)) {
            mmu.dyn.io.IF.serial = true;
            if (self.guest_if) |guest_if| {
                guest_if.serial = true;
            }
        }
    }

    pub fn tick(self: *Serial, mmu: *Fundude.Mmu, clock: u32) void {
        if (clock % master_cycles == 0 and
            mmu.dyn.io.serial.SC.transfer_start_flag and
            mmu.dyn.io.serial.SC.shift_clock == .Internal)
        {
            self.shift(mmu);
        }
    }
};

fn expectMmio(mmio: Fundude.Mmu.Io, SB: u8, IF: bool) !void {
    std.testing.expectEqual(SB, mmio.serial.SB);
    std.testing.expectEqual(IF, mmio.IF.serial);
}

test "basic shift" {
    var serial: Serial = undefined;
    serial.reset();

    var mmu: Fundude.Mmu = undefined;
    var other_mmio: Fundude.Mmu.Io = undefined;

    serial.connect(&other_mmio);

    mmu.dyn.io.IF.serial = false;
    other_mmio.IF.serial = false;

    mmu.dyn.io.serial.SB = 0x00;
    other_mmio.serial.SB = 0xFF;

    serial.shift(&mmu);
    try expectMmio(mmu.dyn.io, 0x01, false);
    try expectMmio(other_mmio, 0xFE, false);

    serial.shift(&mmu);
    try expectMmio(mmu.dyn.io, 0x03, false);
    try expectMmio(other_mmio, 0xFC, false);

    serial.shift(&mmu);
    try expectMmio(mmu.dyn.io, 0x07, false);
    try expectMmio(other_mmio, 0xF8, false);

    serial.shift(&mmu);
    try expectMmio(mmu.dyn.io, 0x0F, false);
    try expectMmio(other_mmio, 0xF0, false);

    serial.shift(&mmu);
    try expectMmio(mmu.dyn.io, 0x1F, false);
    try expectMmio(other_mmio, 0xE0, false);

    serial.shift(&mmu);
    try expectMmio(mmu.dyn.io, 0x3F, false);
    try expectMmio(other_mmio, 0xC0, false);

    serial.shift(&mmu);
    try expectMmio(mmu.dyn.io, 0x7F, false);
    try expectMmio(other_mmio, 0x80, false);

    serial.shift(&mmu);
    try expectMmio(mmu.dyn.io, 0xFF, true);
    try expectMmio(other_mmio, 0x00, true);
}
