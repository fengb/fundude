const std = @import("std");

const main = @import("main.zig");

const Cpu = @import("Cpu.zig");
const joypad = @import("joypad.zig");
const serial = @import("serial.zig");
const timer = @import("timer.zig");
const audio = @import("audio.zig");
const video = @import("video.zig");

const BEYOND_CART = 0x8000;
const BANK_SIZE = 0x4000;

pub const Io = extern struct {
    joypad: joypad.Io, // [$FF00]
    serial: serial.Io, // [$FF01 - $FF02]
    _pad_ff03: u8,
    timer: timer.Io, // [$FF04 - $FF07]
    _pad_ff08_0e: [7]u8, // [$FF08 - $FF0E]
    IF: Cpu.Irq, // [$FF0F]
    audio: audio.Io, // [$FF10 - $FF3F]
    video: video.Io, // [$FF40 - $FF4C]
    _pad_ff4d_4f: [4]u8, // [$FF4D - $FF4F]
    boot_complete: u8, // [$FF50] Bootloader sets this on 0x00FE
    _pad_ff51: u8,
    _pad_ff52_53: [2]u8,
    _pad_ff54_57: [4]u8,
    _pad_ff54_5f: [8]u8,
    _pad_ff60_7f: [0x0020]u8, // [$FF60 - $FF7F]
};

const CartHeaderError = error{
    CartTypeError,
    RomSizeError,
    RamSizeError,
};

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
        return std.meta.intToEnum(RomSize, raw) catch error.RomSizeError;
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

pub const Mbc = enum {
    None = 0x0,
    Mbc1 = 0x1,

    pub fn init(cart: []const u8) CartHeaderError!Mbc {
        const size = try RomSize.init(cart[0x148]);
        if (cart.len != size.bytes()) {
            return error.RomSizeError;
        }

        return std.meta.intToEnum(Mbc, cart[0x147]) catch error.CartTypeError;
    }
};

pub const Mmu = struct {
    dyn: extern struct {
        rom: [0x8000]u8 align(8),
        vram: video.Vram, // [$8000 - $A000)
        switchable_ram: [0x2000]u8, // [$A000 - $C000)
        ram: [0x2000]u8, // [$C000 - $E000)
        _pad_ram_echo: [0x1E00]u8, // [$E000 - $FE00)
        oam: [40]video.SpriteAttr, // [$FE00 - $FEA0)
        _pad_fea0_ff00: [0x0060]u8, // [$FEA0 - $FF00)
        io: Io, // [$FF00 - $FF80)
        high_ram: [0x007F]u8, // [$FF80 - $FFFF)
        interrupt_enable: Cpu.Irq, // [$FFFF]
    },

    cart: []const u8,
    mbc: Mbc,
    bank: u8,

    pub fn reset(self: *Mmu) void {
        // @memset(@ptrCast([*]u8, &self.io), 0, @sizeOf(@typeOf(self.io)));
        @memset(@ptrCast([*]u8, &self.dyn.vram), 0, 0x8000);
    }

    pub fn load(self: *Mmu, cart: []const u8) !void {
        self.mbc = try Mbc.init(cart);
        self.cart = cart;
        self.bank = 1;
        std.mem.copy(u8, &self.dyn.rom, &BOOTLOADER);
        std.mem.copy(u8, self.dyn.rom[BOOTLOADER.len..], cart[BOOTLOADER.len..0x8000]);
    }

    pub fn instrBytes(self: Mmu, addr: u16) [3]u8 {
        return std.mem.asBytes(&self.dyn)[addr..][0..3].*;
    }

    pub fn get(self: Mmu, addr: u16) u8 {
        return std.mem.asBytes(&self.dyn)[addr];
    }

    pub fn set(self: *Mmu, addr: u16, val: u8) void {
        if (addr < BEYOND_CART) {
            return @call(.{ .modifier = .never_inline }, self.setRom, .{ @intCast(u15, addr), val });
        }

        std.mem.asBytes(&self.dyn)[addr] = val;

        // TODO: replace magic with sibling references
        const fd = @fieldParentPtr(main.Fundude, "mmu", self);

        switch (addr) {
            0x8000...0xA000 - 1 => fd.video.updatedVram(self, addr, val),
            0xC000...0xDE00 - 1 => self.dyn.ram[addr - 0xC000] = val, // Echo of 8kB Internal RAM
            0xE000...0xFE00 - 1 => self.dyn.ram[addr - 0xE000] = val, // Echo of 8kB Internal RAM
            0xFE00...0xFEA0 - 1 => fd.video.updatedOam(self, addr, val),
            0xFF00 => fd.inputs.sync(self),
            0xFF40...0xFF4C - 1 => fd.video.updatedIo(self, addr, val),
            0xFF50 => std.mem.copy(u8, &self.dyn.rom, self.cart[0..BOOTLOADER.len]),
            else => {},
        }
    }

    // TODO: RAM banking
    fn setRom(self: *Mmu, addr: u15, val: u8) void {
        switch (self.mbc) {
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
                        self.selectBank(std.math.min(bank, total_banks));
                    },
                    BANK_SIZE...0x6000 - 1 => {}, // RAM bank
                    0x6000...0x8000 - 1 => {}, // ROM/RAM Mode Select
                }
            },
        }
    }

    fn selectBank(self: *Mmu, bank: u8) void {
        if (self.bank == bank) return;

        self.bank = bank;
        const offset = @as(usize, BANK_SIZE) * bank;
        // std.mem.copy(u8, self.dyn.rom[BANK_SIZE..], self.cart[offset..][0..BANK_SIZE]);
        // Not sure why Zig isn't rolling these up -- manually convert to 8 byte copies instead
        std.mem.copy(
            u64,
            @alignCast(8, std.mem.bytesAsSlice(u64, self.dyn.rom[BANK_SIZE..])),
            @alignCast(8, std.mem.bytesAsSlice(u64, self.cart[offset..][0..BANK_SIZE])),
        );
    }
};

const BOOTLOADER = [0x100]u8{
    0x31, 0xfe, 0xff, 0xaf, 0x21, 0xff, 0x9f, 0x32, 0xcb, 0x7c, 0x20, 0xfb, 0x21, 0x26, 0xff, 0x0e,
    0x11, 0x3e, 0x80, 0x32, 0xe2, 0x0c, 0x3e, 0xf3, 0xe2, 0x32, 0x3e, 0x77, 0x77, 0x3e, 0xfc, 0xe0,
    0x47, 0x11, 0x04, 0x01, 0x21, 0x10, 0x80, 0x1a, 0xcd, 0x95, 0x00, 0xcd, 0x96, 0x00, 0x13, 0x7b,
    0xfe, 0x34, 0x20, 0xf3, 0x11, 0xd8, 0x00, 0x06, 0x08, 0x1a, 0x13, 0x22, 0x23, 0x05, 0x20, 0xf9,
    0x3e, 0x19, 0xea, 0x10, 0x99, 0x21, 0x2f, 0x99, 0x0e, 0x0c, 0x3d, 0x28, 0x08, 0x32, 0x0d, 0x20,
    0xf9, 0x2e, 0x0f, 0x18, 0xf3, 0x67, 0x3e, 0x64, 0x57, 0xe0, 0x42, 0x3e, 0x91, 0xe0, 0x40, 0x04,
    0x1e, 0x02, 0x0e, 0x0c, 0xf0, 0x44, 0xfe, 0x90, 0x20, 0xfa, 0x0d, 0x20, 0xf7, 0x1d, 0x20, 0xf2,
    0x0e, 0x13, 0x24, 0x7c, 0x1e, 0x83, 0xfe, 0x62, 0x28, 0x06, 0x1e, 0xc1, 0xfe, 0x64, 0x20, 0x06,
    0x7b, 0xe2, 0x0c, 0x3e, 0x87, 0xe2, 0xf0, 0x42, 0x90, 0xe0, 0x42, 0x15, 0x20, 0xd2, 0x05, 0x20,
    0x4f, 0x16, 0x20, 0x18, 0xcb, 0x4f, 0x06, 0x04, 0xc5, 0xcb, 0x11, 0x17, 0xc1, 0xcb, 0x11, 0x17,
    0x05, 0x20, 0xf5, 0x22, 0x23, 0x22, 0x23, 0xc9, 0xce, 0xed, 0x66, 0x66, 0xcc, 0x0d, 0x00, 0x0b,
    0x03, 0x73, 0x00, 0x83, 0x00, 0x0c, 0x00, 0x0d, 0x00, 0x08, 0x11, 0x1f, 0x88, 0x89, 0x00, 0x0e,
    0xdc, 0xcc, 0x6e, 0xe6, 0xdd, 0xdd, 0xd9, 0x99, 0xbb, 0xbb, 0x67, 0x63, 0x6e, 0x0e, 0xec, 0xcc,
    0xdd, 0xdc, 0x99, 0x9f, 0xbb, 0xb9, 0x33, 0x3e, 0x3c, 0x42, 0xb9, 0xa5, 0xb9, 0xa5, 0x42, 0x3c,
    0x21, 0x04, 0x01, 0x11, 0xa8, 0x00, 0x1a, 0x13, 0xbe, 0x20, 0xfe, 0x23, 0x7d, 0xfe, 0x34, 0x20,
    0xf5, 0x06, 0x19, 0x78, 0x86, 0x23, 0x05, 0x20, 0xfb, 0x86, 0x20, 0xfe, 0x3e, 0x01, 0xe0, 0x50,
};
