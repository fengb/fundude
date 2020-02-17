const std = @import("std");
const main = @import("main.zig");

pub const Io = packed struct {
    // Square 1
    NR10: packed struct { // $FF10
        shift: u3,
        direction: enum(u1) {
            addition = 0,
            subtraction = 1,
        },
        period: u3,
        _pad: u1,
    },
    NR11: DutyLength, // $FF11
    NR12: Volume, // $FF12
    NR13_14: Frequency, // $FF13-FF14

    // Square 2
    _pad_ff15: u8,
    NR21: DutyLength, // $FF16
    NR22: Volume, // $FF17
    NR23_24: Frequency, // $FF18-FF19

    // Wave
    NR30: packed struct { // $FF1A
        _pad: u7,
        active: bool,
    },
    NR31: u8, // $FF1B
    NR32: packed struct { // $FF1C
        _pad1: u5,
        volume: enum(u2) {
            Mute = 0,
            Max = 1,
            Half = 2,
            Quarter = 3,
        },
        _pad2: u1,
    },
    NR33_34: Frequency, // $FF1D-FF1E
    _pad_ff1f: u8,

    // Noise
    NR41: DutyLength, // $FF20
    NR42: Volume, // $FF21
    NR43: packed struct { // $FF22
        divisor: u3,
        width: enum(u1) { _15 = 0, _7 = 1 },
        shift: u4,
    },
    NR44: packed struct { // $FF23
        _pad: u6,
        length_enabled: bool,
        reset: bool,
    },

    // Control / Status
    NR50: packed struct { // $FF24
        right_volume: u3,
        right_vin: u1,
        left_volume: u3,
        left_vin: u1,
    },
    NR51: packed struct { // $FF25
        right: ChannelOn,
        left: ChannelOn,
    },
    NR52: packed struct { // $FF26
        on: ChannelOn,
        _pad: u3,
        master: bool,
    },

    // TODO: Zig can't handle misaligned arrays
    _pad_ff27: u8,
    _pad_ff28_2f: [8]u8,

    wave_table: [0x10]u8, // $FF30 - FF3F
};

const DutyLength = packed struct {
    length: u6,
    duty: u2,
};

const Volume = packed struct {
    period: u3,
    envelope: u1,
    initial: u4,
};

const Frequency = packed struct {
    data: u11,
    _pad1: u1,
    _pad2: u2,
    length_enabled: bool,
    reset: bool,
};

const ChannelOn = packed struct {
    Square1: bool,
    Square2: bool,
    Wave: bool,
    Noise: bool,
};

pub const cycles_per_sample = 44; // 4MHz / 44 = 95.325kHz
pub const samples_per_frame = @divExact(main.CYCLES_PER_FRAME, cycles_per_sample);

pub const Audio = struct {
    buffer0: [samples_per_frame]f32,
    buffer1: [samples_per_frame]f32,

    out: []f32,
    gen: []f32,

    fn reset(self: *Audio) void {
        std.mem.set(f32, self.buffer0[0..], 0);
        self.out = &self.buffer0;
        self.gen = &self.buffer1;
    }

    pub fn step(self: *Audio, mmu: *main.Mmu, cycles: u16) void {
        if (!mmu.dyn.io.audio.NR52.master) {
            return;
        }
    }
};
