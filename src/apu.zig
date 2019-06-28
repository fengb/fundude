pub const Io = struct {
    NR10: u8, // $FF10
    NR11: u8, // $FF11
    NR12: u8, // $FF12
    NR13: u8, // $FF13
    NR14: u8, // $FF14
    NR21: u8, // $FF15
    NR22: u8, // $FF16
    NR23: u8, // $FF17
    NR24: u8, // $FF18
    _pad_ff1a: u8,
    NR30: u8, // $FF1A
    NR31: u8, // $FF1B
    NR32: u8, // $FF1C
    NR33: u8, // $FF1D
    NR34: u8, // $FF1E
    _pad_ff1f: u8,

    NR41: u8, // $FF20
    NR42: u8, // $FF21
    NR43: u8, // $FF22
    NR44: u8, // $FF23
    NR50: u8, // $FF24
    NR51: u8, // $FF25
    NR52: u8, // $FF26
    _pad_ff27_2f: [9]u8,

    wave_pattern: [0x10]u8, // $FF30 - FF3F
};
