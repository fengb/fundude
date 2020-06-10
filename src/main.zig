const std = @import("std");

pub const Cpu = @import("Cpu.zig");
const video = @import("video.zig");
pub const Video = video.Video;
const joypad = @import("joypad.zig");
pub const Mmu = @import("Mmu.zig");
const timer = @import("timer.zig");
pub const Timer = timer.Timer;
pub const Savestate = @import("Savestate.zig");
pub const Temportal = @import("Temportal.zig");

pub const MHz = 4194304;

const Fundude = @This();

allocator: *std.mem.Allocator,

video: video.Video,
cpu: Cpu,
mmu: Mmu,

inputs: joypad.Inputs,
timer: timer.Timer,
temportal: Temportal,

step_underflow: i32,
breakpoint: u16,

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
    self.temportal.reset();
    self.breakpoint = 0xFFFF;
    self.step_underflow = 0;
}

pub fn step(self: *Fundude) i8 {
    // TODO: make cpu.step advance a consistent duration=4
    const duration = @call(.{ .modifier = .never_inline }, self.cpu.step, .{&self.mmu});
    std.debug.assert(duration > 0);

    @call(.{ .modifier = .never_inline }, self.video.step, .{ &self.mmu, duration });
    @call(.{ .modifier = .never_inline }, self.timer.step, .{ &self.mmu, duration });
    @call(.{ .modifier = .never_inline }, self.temportal.step, .{ self, duration });

    return @intCast(i8, duration);
}

pub const dump = Savestate.dump;
pub const restore = Savestate.restore;
pub const validateSavestate = Savestate.validate;
pub const savestate_size = Savestate.size;

test "" {
    _ = Fundude;
    _ = savestate;
}
