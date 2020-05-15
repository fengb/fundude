const std = @import("std");
pub const Cpu = @import("Cpu.zig");
const video = @import("video.zig");
const joypad = @import("joypad.zig");
const mmu = @import("mmu.zig");
const timer = @import("timer.zig");

pub const Mmu = mmu.Mmu;

pub const WIDTH = 160;
pub const HEIGHT = 144;

pub const MHz = 4194304;

pub const Fundude = struct {
    allocator: *std.mem.Allocator,

    video: video.Video,
    cpu: Cpu,
    mmu: mmu.Mmu,

    inputs: joypad.Inputs,
    timer: timer.Timer,

    step_underflow: i32,
    breakpoint: u16,
    disassembly: [24]u8,

    pub fn init(allocator: *std.mem.Allocator) !*Fundude {
        var fd = try allocator.create(Fundude);
        fd.allocator = allocator;
        return fd;
    }

    pub fn deinit(self: *Fundude) void {
        self.allocator.destroy(self);
        self.* = undefined;
    }

    pub fn load(self: *Fundude, cart: []const u8) !void {
        try self.mmu.load(cart);
        self.reset();
    }

    pub fn reset(self: *Fundude) void {
        self.mmu.reset();
        self.video.reset();
        self.cpu.reset();
        self.inputs.reset();
        self.timer.reset();
        self.step_underflow = 0;
    }
};
