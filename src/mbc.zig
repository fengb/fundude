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
            ._32k => 32 * 1024,
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
    cart: []const u8,
    bank_offset: u32,
    id: Id,

    const Id = enum {
        None = 0x0,
        Mbc1 = 0x1,
    };

    // TODO: RAM banking

    pub fn init(cart: []const u8) CartHeaderError!Mbc {
        const size = try RomSize.init(cart[0x148]);
        if (cart.len != size.bytes()) {
            return error.RomSizeError;
        }

        return Mbc{
            .cart = cart,
            .bank_offset = BANK_SIZE,
            .id = std.meta.intToEnum(Id, cart[0x147]) catch return error.CartTypeError,
        };
    }

    pub fn bankIdx(self: Mbc, addr: u16) usize {
        std.debug.assert(addr >= 0x4000);
        std.debug.assert(addr < 0x8000);
        return self.bank_offset + (addr - BANK_SIZE);
    }

    pub fn get(self: Mbc, addr: u15) u8 {
        if (addr < BANK_SIZE) {
            return self.cart[addr];
        } else {
            return self.cart[self.bankIdx(addr)];
        }
    }

    pub fn set(self: *Mbc, addr: u15, val: u8) void {
        switch (self.id) {
            .None => {},
            .Mbc1 => {
                switch (addr) {
                    0x0000...0x2000 - 1 => {}, // RAM enable
                    0x2000...BANK_SIZE - 1 => {
                        var bank = val & 0x1F;
                        if (bank % 0x20 == 0) {
                            bank += 1;
                        }
                        const total_banks = self.cart.len / BANK_SIZE;
                        self.bank_offset = @as(u32, BANK_SIZE) * std.math.min(bank, total_banks);
                    },
                    BANK_SIZE...0x6000 - 1 => {}, // RAM bank
                    0x6000...0x8000 - 1 => {}, // ROM/RAM Mode Select
                }
            },
        }
    }
};
