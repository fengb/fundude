const std = @import("std");

pub const Flags = packed struct {
    vblank: bool,
    lcd_stat: bool,
    timer: bool,
    serial: bool,
    joypad: bool,
    _pad: u3,

    pub const Pos = enum(u3) {
        vblank,
        lcd_stat,
        timer,
        serial,
        joypad,

        fn mask(self: Pos) u8 {
            return @as(u8, 1) << @enumToInt(self);
        }
    };

    pub fn cmp(self: Flags, other: Flags) Flags {
        return @bitCast(Flags, @bitCast(u8, self) & @bitCast(u8, other));
    }

    pub fn get(self: Flags, pos: Pos) bool {
        return pos.mask() & @bitCast(u8, self) != 0;
    }

    pub fn active(self: Flags) ?Pos {
        const raw = @ctz(u8, @bitCast(u8, self));
        return std.meta.intToEnum(Pos, raw) catch null;
    }

    pub fn disable(self: *Flags, pos: Pos) void {
        self.* = @bitCast(Flags, (~pos.mask()) & @bitCast(u8, self.*));
    }
};
