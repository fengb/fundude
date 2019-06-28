// Gamepad

pub const Io = packed struct {
    read: u4,
    dpad: u1,
    button: u1,
    _padding: u2,
};

pub const Inputs = packed struct {
    right: u1,
    left: u1,
    up: u1,
    down: u1,
    a: u1,
    b: u1,
    select: u1,
    start: u1,
};
