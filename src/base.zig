pub const cpu = @import("cpu.zig");
const video = @import("video.zig");
const joypad = @import("joypad.zig");
const mmu = @import("mmu.zig");
const timer = @import("timer.zig");

pub const Cpu = cpu.Cpu;
pub const Mmu = mmu.Mmu;

pub const WIDTH = 160;
pub const HEIGHT = 144;

pub const MHz = 4194304;

pub const Fundude = struct {
    video: video.Video,
    cpu: cpu.Cpu,
    mmu: mmu.Mmu,

    inputs: joypad.Inputs,
    timer: timer.Timer,

    step_underflow: i32,
    breakpoint: u16,
    disassembly: [24]u8,
};
