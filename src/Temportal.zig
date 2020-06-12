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

    // Rewind semantics are similar to CD player:
    //     If currently elapsed < 0.5s, go to previous track
    //     Otherwise go to beginning of current track
    if (self.clock < Fundude.MHz / 2) {
        self.top -%= 1;
    }
    self.clock = 0;

    // Off by 1 errors galore
    if (self.top == self.bottom) {
        self.top +%= 1;
    }
    self.states[self.top -% 1].restoreInto(fd) catch unreachable;
}
