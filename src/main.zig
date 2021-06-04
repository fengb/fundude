const std = @import("std");
const root = @import("root");

pub const Cpu = @import("Cpu.zig");
pub const video = @import("video.zig");
pub const Video = video.Video;
const joypad = @import("joypad.zig");
pub const Mmu = @import("Mmu.zig");
const timer = @import("timer.zig");
pub const Timer = timer.Timer;
pub const Savestate = @import("Savestate.zig");
pub const Temportal = @import("Temportal.zig");

pub const MHz = 4194304;
const CYCLES_PER_MS = Fundude.MHz / 1000;

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

pub fn step(self: *Fundude) i8 {
    self.tick(false);
    var duration: i8 = 4;
    while (self.cpu.remaining > 0) {
        self.tick(false);
        duration += 4;
    }
    return duration;
}

pub fn step_ms(self: *Fundude, ms: i64, is_profiling: bool) i32 {
    const cycles = ms * CYCLES_PER_MS;
    std.debug.assert(cycles < std.math.maxInt(i32));
    return self.step_cycles(@truncate(i32, cycles), is_profiling);
}

pub fn step_cycles(self: *Fundude, cycles: i32, is_profiling: bool) i32 {
    const target_cycles: i32 = cycles;
    var track = target_cycles;

    while (track >= 0) {
        const catchup = track > 140_000 and !is_profiling;
        self.tick(catchup);
        track -= 4;

        if (self.breakpoint == self.cpu.reg._16.get(.PC)) {
            return target_cycles - track;
        }
    }

    return target_cycles - track;
}

pub const dump = Savestate.dump;
pub const restore = Savestate.restore;
pub const validateSavestate = Savestate.validate;
pub const savestate_size = Savestate.size;

test {
    std.testing.refAllDecls(@This());
}
