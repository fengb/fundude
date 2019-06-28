// LPT -- because COM is ambiguous

pub const Io = packed struct {
    SB: u8, // $FF01
    SC: u8, // $FF02
};
