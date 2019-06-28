const cpu = @import("cpu.zig");
const ggp = @import("ggp.zig");
const mmu = @import("mmu.zig");

pub const WIDTH = 160;
pub const HEIGHT = 144;

pub const MHz = 4194304;

pub const SysMode = extern enum {
    norm,
    halt,
    stop,
    fatal, // Not a GB mode, this code is bad and we should feel bad
};

pub const Fundude = struct {
    display: [HEIGHT][WIDTH]u8,

    patterns: [128][192]u8,
    sprites: [32][160]u8,
    background: [256][256]u8,
    window: [256][256]u8,

    cpu: cpu.Cpu,
    mmu: mmu.Mmu,

    interrupt_master: bool,

    inputs: ggp.Inputs,

    clock: struct {
        cpu: i32,
        ppu: i32,
        timer: u16,
    },

    breakpoint: u16,
    disassembly: [24]u8,

    mode: SysMode,
};
