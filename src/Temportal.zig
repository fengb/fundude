const std = @import("std");
const Fundude = @import("main.zig");

const Temportal = @This();

states: [5 * 60]Fundude.Savestate,
top: usize,
clock: usize,

pub fn reset(self: *Temportal) void {
    self.top = 0;
    self.clock = 0;
}

pub fn step(self: *Temportal, fd: *Fundude, cycles: u8) void {
    self.clock +%= cycles;

    if (self.clock >= Fundude.MHz) {
        self.clock -= Fundude.MHz;
        self.states[self.top].dumpFrom(fd.*);
        self.top += 1;
    }
}

pub fn rewind(self: *Temportal, fd: *Fundude) void {
    self.top -= 1;
    self.clock = 0;

    self.states[self.top].restoreInto(fd) catch unreachable;
}
