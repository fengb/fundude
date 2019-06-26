export const cpu_cond = enum(u32) {
    CPU_COND_NZ,
    CPU_COND_Z,
    CPU_COND_NC,
    CPU_COND_C,
};

export const cpu_reg8 = extern struct {
    _: u8,
};

export const cpu_reg16 = extern union {
    _: u16,
    x: struct {
        _1: cpu_reg8,
        _0: cpu_reg8,
    },
};

export const cpu = extern struct {
    AF: cpu_reg16,
    BC: cpu_reg16,
    DE: cpu_reg16,
    HL: cpu_reg16,
    SP: cpu_reg16,
    PC: cpu_reg16,
};
