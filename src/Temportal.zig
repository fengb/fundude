const std = @import("std");
const Fundude = @import("main.zig");

const Temportal = @This();

states: []Fundude.Savestate = &.{},
bottom: usize = 0,
top: usize = 0,
clock: usize = 0,

pub fn init(self: *Temportal, allocator: *std.mem.Allocator, states: usize) !void {
    if (self.states.len != states) {
        self.states = try allocator.realloc(self.states, states);
    }
    self.bottom = 0;
    self.top = 0;
    self.clock = 0;
}

pub fn deinit(self: *Temportal, allocator: *std.mem.Allocator) void {
    allocator.free(self.states);
    self.* = .{};
}

pub fn tick(self: *Temportal, fd: *Fundude) void {
    self.clock +%= 4;

    if (self.clock >= Fundude.MHz) {
        self.clock -= Fundude.MHz;

        self.save(fd);
    }
}

pub fn save(self: *Temportal, fd: *Fundude) void {
    if (self.states.len == 0) return;

    self.states[self.top].dumpFrom(fd.*);
    self.top += 1;
    if (self.top >= self.states.len) {
        self.top = 0;
    }

    if (self.top == self.bottom) {
        self.bottom += 1;
        if (self.bottom >= self.states.len) {
            self.bottom = 0;
        }
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
