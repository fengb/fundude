const main = @import("main.zig");

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
    clock: u16,
    timer: u32,

    pub fn reset(self: *Timer) void {
        self.clock = 0;
        self.timer = 0;
    }

    pub fn step(self: *Timer, mmu: *main.Mmu, cycles: u8) void {
        self.clock +%= cycles;
        mmu.dyn.io.timer.DIV = @intCast(u8, self.clock / 256);

        if (!mmu.dyn.io.timer.TAC.active) {
            return;
        }

        self.timer += cycles;
        if (self.timer >= mmu.dyn.io.timer.TAC.speed.frequency()) {
            self.timer -= mmu.dyn.io.timer.TAC.speed.frequency();

            if (mmu.dyn.io.timer.TIMA != 0xFF) {
                mmu.dyn.io.timer.TIMA +%= 1;
            } else {
                // TODO: this effect actually happen 1 cycle later
                mmu.dyn.io.timer.TIMA = mmu.dyn.io.timer.TMA;
                mmu.dyn.io.IF.timer = true;
            }
        }
    }
};

const Speed = packed enum(u2) {
    _4096 = 0, // 1024 cycles
    _262144 = 1, // 16 cycles
    _65536 = 2, // 64 cycles
    _16384 = 3, // 256 cycles

    pub fn frequency(self: Speed) u32 {
        return switch (self) {
            ._4096 => 4096,
            ._16384 => 16384,
            ._65536 => 65536,
            ._262144 => 262144,
        };
    }
};
