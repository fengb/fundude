pub const cond = enum(u32) {
    nz,
    z,
    nc,
    c,
};

pub const Reg8 = packed struct {
    _: u8,
};

pub const Reg16 = packed union {
    _: u16,
    x: struct {
        _1: Reg8,
        _0: Reg8,
    },
};

pub const Cpu = packed struct {
    AF: Reg16,
    BC: Reg16,
    DE: Reg16,
    HL: Reg16,
    SP: Reg16,
    PC: Reg16,
};

pub const Result = struct {
    jump: u16,
    length: u16,
    duration: u8,
    zasm: []const u8,
};
