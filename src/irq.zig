pub const Flags = packed struct {
    vblank: bool,
    lcd_stat: bool,
    timer: bool,
    serial: bool,
    joypad: bool,
    _pad: u3,
};

pub const Irq = struct {
    master: bool,
};
