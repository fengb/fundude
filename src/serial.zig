const std = @import("std");

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
const buffer_size = 1024;

const Fifo = std.fifo.LinearFifo(u8, std.fifo.LinearFifoBufferType{ .Static = buffer_size });

pub const Serial = struct {
    clock: usize,

    buffer_in: Fifo,
    buffer_out: [buffer_size]u8,
    buffer_out_cur: usize,

    shift_in: u8,
    shift_out: u8,
    current_bit: u3,

    pub fn reset(self: *Serial) void {
        self.clock = 0;
        self.buffer_in = Fifo.init();
        self.buffer_out_cur = 0;
        self.shift_in = 0xFF;
        self.shift_out = 0xFF;
        self.current_bit = 7;
    }

    fn getBit(val: u8, pos: u3) u8 {
        return val >> pos & 1;
    }

    pub fn out(self: *Serial) []u8 {
        defer self.buffer_out_cur = 0;
        return self.buffer_out[0..self.buffer_out_cur];
    }

    pub fn shift(self: *Serial, mmu: *base.Mmu) void {
        self.shift_out |= getBit(mmu.dyn.io.serial.SB, 7) << self.current_bit;
        mmu.dyn.io.serial.SB = mmu.dyn.io.serial.SB << 1 | getBit(self.shift_in, self.current_bit);

        self.current_bit -= 1;

        if (self.current_bit == 7) {
            self.shift_in = self.buffer_in.readItem() catch 0xFF;
            self.buffer_out.writeItem(self.shift_out);
            mmu.dyn.io.IF.serial = true;
        }
    }

    pub fn step(self: *Serial, mmu: *base.Mmu, cycles: u8) void {
        if (!mmu.dyn.io.serial.SC.transfer_start_flag or
            mmu.dyn.io.serial.SC.shift_clock == .External) return;

        self.clock +%= cycles;
        if (self.clock >= master_cycles) {
            self.clock -= master_cycles;
            self.shift(mmu);
        }
    }
};
