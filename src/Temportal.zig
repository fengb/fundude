const std = @import("std");
const Fundude = @import("main.zig");

const Temportal = @This();

states: [256]Fundude.Savestate,
bottom: u8,
top: u8,
clock: usize,

pub fn reset(self: *Temportal) void {
    self.bottom = 0;
    self.top = 0;
    self.clock = 0;
}

pub fn step(self: *Temportal, fd: *Fundude, cycles: u8) void {
    self.clock +%= cycles;

    if (self.clock >= Fundude.MHz) {
        self.clock -= Fundude.MHz;

        self.save(fd);
    }
}

pub fn save(self: *Temportal, fd: *Fundude) void {
    self.states[self.top].dumpFrom(fd.*);
    self.top +%= 1;
    if (self.top == self.bottom) {
        self.bottom +%= 1;
    }
}

pub fn rewind(self: *Temportal, fd: *Fundude) void {
    if (self.bottom == self.top) return;

    self.clock = 0;
    self.top -%= 1;

    self.states[self.top].restoreInto(fd) catch unreachable;

    if (self.top == self.bottom) {
        self.top +%= 1;
    }
}
