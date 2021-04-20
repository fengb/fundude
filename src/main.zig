const std = @import("std");
const root = @import("root");

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
pub const profiling_call = std.builtin.CallOptions{
    .modifier = if (@hasDecl(root, "is_profiling") and root.is_profiling) .never_inline else .auto,
};

const Fundude = @This();

video: video.Video = undefined,
cpu: Cpu = undefined,
mmu: Mmu = undefined,

inputs: joypad.Inputs = undefined,
timer: timer.Timer = undefined,
temportal: Temportal = .{},

breakpoint: u16 = 0xFFFF,

pub fn init(self: *Fundude, allocator: *std.mem.Allocator, args: struct {
    cart: ?[]const u8 = null,
    temportal_states: usize = 256,
}) !void {
    if (args.cart) |cart| {
        try self.mmu.load(cart);
    }

    try self.temportal.init(allocator, args.temportal_states);
    self.temportal.save(self);

    self.mmu.reset();
    self.video.reset();
    self.cpu.reset();
    self.inputs.reset();
    self.timer.reset();

    self.breakpoint = 0xFFFF;
}

pub fn deinit(self: *Fundude, allocator: *std.mem.Allocator) void {
    self.temportal.deinit(allocator);
    self.* = .{};
}

// TODO: convert "catchup" to an enum
pub fn tick(self: *Fundude, catchup: bool) void {
    @call(Fundude.profiling_call, self.cpu.tick, .{&self.mmu});
    @call(Fundude.profiling_call, self.video.tick, .{ &self.mmu, catchup });
    @call(Fundude.profiling_call, self.timer.tick, .{&self.mmu});
    @call(Fundude.profiling_call, self.temportal.tick, .{self});
}

pub const dump = Savestate.dump;
pub const restore = Savestate.restore;
pub const validateSavestate = Savestate.validate;
pub const savestate_size = Savestate.size;

test {
    std.testing.refAllDecls(@This());
}
