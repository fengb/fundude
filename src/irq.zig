pub const FlagName = enum {
    vblank,
    lcd_stat,
    timer,
    serial,
    joypad,
};

pub const Flags = packed struct {
    vblank: bool,
    lcd_stat: bool,
    timer: bool,
    serial: bool,
    joypad: bool,
    _pad: u3,

    pub fn cmp(self: Flags, other: Flags) Flags {
        return @bitCast(Flags, @bitCast(u8, self) & @bitCast(u8, other));
    }

    pub fn active(self: Flags) ?FlagName {
        return if (self.vblank)
            FlagName.vblank
        else if (self.lcd_stat)
            FlagName.lcd_stat
        else if (self.timer)
            FlagName.lcd_stat
        else if (self.serial)
            FlagName.serial
        else if (self.joypad)
            FlagName.joypad
        else
            null;
    }
};
