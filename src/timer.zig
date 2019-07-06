const base = @import("base.zig");

pub const Io = packed struct {
    DIV: u8, // $FF04
    TIMA: u8, // $FF05
    TMA: u8, // $FF06
    TAC: packed struct {
        speed: Speed,
        active: bool,
        _pad: u5,
    },
};

pub const Timer = struct {
    _: u16,

    pub fn step(self: *Timer, mmu: *base.Mmu, cycles: u8) void {
        self._ +%= cycles;
        mmu.io.timer.DIV = @intCast(u8, self._ / 256);

        if (!mmu.io.timer.TAC.active) {
            return;
        }

        const start = mmu.io.timer.TIMA;
        mmu.io.timer.TIMA +%= mmu.io.timer.TAC.speed.timaShift(cycles);
        const overflowed = mmu.io.timer.TIMA < start;
        if (overflowed) {
            // TODO: this effect actually happen 1 cycle later
            mmu.io.timer.TIMA +%= mmu.io.timer.TMA;
            mmu.io.IF.timer = true;
        }
    }
};

const Speed = packed enum(u2) {
    _4096 = 0,
    _262144 = 1,
    _65536 = 2,
    _16384 = 3,

    pub fn timaShift(self: Speed, cycles: u8) u8 {
        return switch (self) {
            ._4096 => cycles / 4, // 256 / 1024
            ._16384 => cycles * (256 / 256),
            ._65536 => cycles * (256 / 64),
            ._262144 => cycles * (256 / 16),
        };
    }
};
