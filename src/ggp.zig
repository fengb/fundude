// Gamepad

pub const Io = packed union {
    _: u8,

    bitfields: packed struct {
        read: u4,
        dpad: u1,
        buttons: u1,
        _padding: u2,
    },

    pub fn set(self: *Io, val: u8, inputs: Inputs) void {
        self._ = val;
        self.sync(inputs);
    }

    pub fn sync(self: *Io, inputs: Inputs) void {
        // Hardware quirk: 0 == active
        if (self.bitfields.buttons == 0) {
            self.bitfields.read = ~inputs.nibbles.buttons;
            return;
        }
        if (self.bitfields.dpad == 0) {
            self.bitfields.read = ~inputs.nibbles.dpad;
            return;
        }
    }
};

pub const Inputs = packed union {
    _: u8,

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

    pub fn update(self: Inputs, io: *Io) void {
        io.sync(self);
    }
};
