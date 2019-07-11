const std = @import("std");

const RomSize = enum(u8) {
    _32k = 0,
    _64k = 1,
    _128k = 2,
    _256k = 3,
    _512k = 4,
    _1m = 5,
    _2m = 6,
    _4m = 7,
    _8m = 8,

    pub fn bytes(self: RomSize) usize {
        return switch (self) {
            ._32k => usize(32 * 1024),
            ._64k => 64 * 1024,
            ._128k => 128 * 1024,
            ._256k => 256 * 1024,
            ._512k => 512 * 1024,
            ._1m => 1024 * 1024,
            ._2m => 2 * 1024 * 1024,
            ._4m => 4 * 1024 * 1024,
            ._8m => 8 * 1024 * 1024,
        };
    }
};

const RamSize = enum(u8) {
    _0 = 0,
    _2k = 1,
    _8k = 2,
    _32k = 3,
    _128k = 4,
    _64k = 5,
};

pub const Mbc = struct {
    cart: []u8,

    pub fn load(self: *Mbc, cart: []u8) void {
        // Convert asserts to real errors
        std.debug.assert(cart.len >= 32 * 1024);
        const size = @intToEnum(RomSize, cart[0x148]);
        std.debug.assert(cart.len == size.bytes());

        self.cart = cart;
    }

    // TODO: remove me
    pub fn ptr(self: Mbc, addr: u16) [*]u8 {
        return self.cart.ptr + addr;
    }

    pub fn get(self: Mbc, addr: u16) u8 {
        return cart[addr];
    }

    pub fn set(self: *Mbc, addr: u16, val: u8) void {}
};
