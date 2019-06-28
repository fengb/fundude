const ggp = @import("ggp.zig");
const lpt = @import("lpt.zig");
const timer = @import("timer.zig");
const irq = @import("irq.zig");
const apu = @import("apu.zig");
const ppu = @import("ppu.zig");

pub const Io = struct {
    ggp: ggp.Io, // [$FF00]
    lpt: lpt.Io, // [$FF01 - $FF02]
    _pad_ff03: u8,
    timer: timer.Io, // [$FF04 - $FF07]
    _pad_ff08_0e: [7]u8, // [$FF08 - $FF0E]
    IF: irq.Flags, // [$FF0F]
    apu: apu.Io, // [$FF10 - $FF3F]
    ppu: ppu.Io, // [$FF40 - $FF4C]
    _pad_ff4d_4f: [0x0004]u8, // [$FF4D - $FF4F]
    boot_complete: u8, // [$FF50] Bootloader sets this on 0x00FE
    _pad_ff51_7f: [0x002F]u8, // [$FF51 - $FF7f]
};

pub const Mmu = struct {
    vram: ppu.Vram, // [$8000 - $A000)
    switchable_ram: [0x2000]u8, // [$A000 - $C000)
    ram: [0x2000]u8, // [$C000 - $E000)
    _pad_ram_echo: [0x1E00]u8, // [$E000 - $FE00)
    oam: [40]ppu.SpriteAttr, // [$FE00 - $FEA0)
    _pad_fea0_ff00: [0x0060]u8, // [$FEA0 - $FF00)
    io: Io, // [$FF00 - $FF80)
    high_ram: [0x007F]u8, // [$FF80 - $FFFF)
    interrupt_enable: irq.Flags, // [$FFFF]

    cart: []u8, // 0x0000 - 0x8000
};
