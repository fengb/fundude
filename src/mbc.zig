const std = @import("std");

const CartHeaderError = error{
    CartTypeError,
    RomSizeError,
    RamSizeError,
};

const BANK_SIZE = 0x4000;

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

    pub fn init(raw: u8) !RomSize {
        if (raw >= 8) {
            return error.RomSizeError;
        }
        return @intToEnum(RomSize, raw);
    }

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

const Nope = struct {
    pub fn set(mbc: *Mbc, addr: u15, val: u8) void {}
};

const Mbc1 = struct {
    pub fn set(mbc: *Mbc, addr: u15, val: u8) void {
        if (addr < 0x2000) {
            // RAM enable
        } else if (addr < BANK_SIZE) {
            var bank = val & 0x1F;
            if (bank % 0x20 == 0) {
                bank += 1;
            }
            const total_banks = mbc.cart.len / BANK_SIZE;
            mbc.bank_offset = u32(BANK_SIZE) * std.math.min(bank, total_banks);
        } else if (addr < 0x6000) {
            // RAM bank
        } else {
            // ROM/RAM Mode Select
        }
    }
};

pub const Mbc = struct {
    cart: []u8,
    bank_offset: u32,

    // TODO: convert to getFn
    setFn: fn (mbc: *Mbc, addr: u15, val: u8) void,

    // TODO: RAM banking

    pub fn load(self: *Mbc, cart: []u8) CartHeaderError!void {
        const size = try RomSize.init(cart[0x148]);
        if (cart.len != size.bytes()) {
            return error.RomSizeError;
        }

        switch (cart[0x147]) {
            0x0 => {
                self.setFn = Nope.set;
            },
            0x1 => {
                self.setFn = Mbc1.set;
            },
            else => return error.CartTypeError,
        }
        self.cart = cart;
        self.bank_offset = BANK_SIZE;
    }

    // TODO: remove me
    pub fn ptr(self: Mbc, addr: u15) [*]const u8 {
        if (addr < BANK_SIZE) {
            return self.cart.ptr + addr;
        } else {
            return self.cart.ptr + self.bank_offset + (addr - BANK_SIZE);
        }
    }

    pub fn get(self: Mbc, addr: u15) u8 {
        const p = self.ptr(addr);
        return p[0];
    }

    pub fn set(self: *Mbc, addr: u15, val: u8) void {
        return self.setFn(self, addr, val);
    }
};
