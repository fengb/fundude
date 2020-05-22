const std = @import("std");

pub const Cpu = @import("Cpu.zig");
const video = @import("video.zig");
const joypad = @import("joypad.zig");
pub const mmu = @import("mmu.zig");
pub const Mmu = @import("mmu.zig").Mmu;
const timer = @import("timer.zig");

pub const MHz = 4194304;

const Fundude = @This();

allocator: *std.mem.Allocator,

video: video.Video,
cpu: Cpu,
mmu: Mmu,

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

pub fn step(self: *Fundude) i8 {
    const duration = @call(.{ .modifier = .never_inline }, self.cpu.step, .{&self.mmu});
    std.debug.assert(duration > 0);

    @call(.{ .modifier = .never_inline }, self.video.step, .{ &self.mmu, duration });
    @call(.{ .modifier = .never_inline }, self.timer.step, .{ &self.mmu, duration });

    return @intCast(i8, duration);
}

test "" {
    _ = Fundude;
}
