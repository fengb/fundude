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
    current_bit: u3,

    pub fn reset(self: *Serial) void {
        self.guest_sb = null;
        self.current_bit = 0;
    }

    fn getBit(val: u8, pos: u3) u8 {
        return val >> pos & 1;
    }

    const zero: u8 = 0;

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
