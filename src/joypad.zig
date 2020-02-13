const main = @import("main.zig");

pub const Io = packed union {
    _: u8,

    bitfields: packed struct {
        read: u4,
        dpad: u1,
        buttons: u1,
        _padding: u2,
    },
};

pub const Inputs = packed union {
    raw: u8,

    keys: packed struct {
        right: u1,
        left: u1,
        up: u1,
        down: u1,
        a: u1,
        b: u1,
        select: u1,
        start: u1,
    },

    nibbles: packed struct {
        dpad: u4,
        buttons: u4,
    },

    pub fn reset(self: *Inputs) void {
        self.raw = 0;
    }

    pub fn press(self: *Inputs, mmu: *main.Mmu, update: Inputs) bool {
        const changed_to_pressed = (update.raw ^ self.raw) ^ (~self.raw);
        if (changed_to_pressed == 0) return false;

        self.raw |= update.raw;
        self.sync(mmu);
        return true;
    }

    pub fn release(self: *Inputs, mmu: *main.Mmu, update: Inputs) bool {
        const changed_to_released = update.raw & self.raw;
        if (changed_to_released == 0) return false;

        self.raw &= ~update.raw;
        self.sync(mmu);
        return true;
    }

    pub fn sync(self: Inputs, mmu: *main.Mmu) void {
        // Hardware quirk: 0 == active
        if (mmu.dyn.io.joypad.bitfields.buttons == 0) {
            mmu.dyn.io.joypad.bitfields.read = ~self.nibbles.buttons;
            return;
        }
        if (mmu.dyn.io.joypad.bitfields.dpad == 0) {
            mmu.dyn.io.joypad.bitfields.read = ~self.nibbles.dpad;
            return;
        }
    }
};
