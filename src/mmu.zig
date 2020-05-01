const std = @import("std");

const main = @import("main.zig");

const joypad = @import("joypad.zig");
const serial = @import("serial.zig");
const timer = @import("timer.zig");
const irq = @import("irq.zig");
const audio = @import("audio.zig");
const video = @import("video.zig");
const mbc = @import("mbc.zig");

const BEYOND_BOOTLOADER = 0x100;
const BEYOND_CART = 0x8000;

pub const Io = extern struct {
    joypad: joypad.Io, // [$FF00]
    serial: serial.Io, // [$FF01 - $FF02]
    _pad_ff03: u8,
    timer: timer.Io, // [$FF04 - $FF07]
    _pad_ff08_0e: [7]u8, // [$FF08 - $FF0E]
    IF: irq.Flags, // [$FF0F]
    audio: audio.Io, // [$FF10 - $FF3F]
    video: video.Io, // [$FF40 - $FF4C]
    _pad_ff4d_4f: [0x0004]u8, // [$FF4D - $FF4F]
    boot_complete: u8, // [$FF50] Bootloader sets this on 0x00FE
    _pad_ff51: u8,
    _pad_ff52_53: [2]u8,
    _pad_ff54_57: [4]u8,
    _pad_ff54_5f: [8]u8,
    _pad_ff60_7f: [0x0020]u8, // [$FF60 - $FF7F]
};

pub const Mmu = struct {
    dyn: extern struct {
        vram: video.Vram, // [$8000 - $A000)
        switchable_ram: [0x2000]u8, // [$A000 - $C000)
        ram: [0x2000]u8, // [$C000 - $E000)
        _pad_ram_echo: [0x1E00]u8, // [$E000 - $FE00)
        oam: [40]video.SpriteAttr, // [$FE00 - $FEA0)
        _pad_fea0_ff00: [0x0060]u8, // [$FEA0 - $FF00)
        io: Io, // [$FF00 - $FF80)
        high_ram: [0x007F]u8, // [$FF80 - $FFFF)
        interrupt_enable: irq.Flags, // [$FFFF]
    },

    mbc: mbc.Mbc,

    pub fn reset(self: *Mmu) void {
        // @memset(@ptrCast([*]u8, &self.io), 0, @sizeOf(@typeOf(self.io)));
        @memset(@ptrCast([*]u8, &self.dyn), 0, 0x8000);
    }

    pub fn load(self: *Mmu, cart: []const u8) !void {
        self.mbc = try mbc.Mbc.init(cart);
    }

    fn get(self: *Mmu, addr: u16) u8 {
        if (self.dyn.io.boot_complete == 0 and addr < BEYOND_BOOTLOADER) {
            return BOOTLOADER[addr];
        }

        if (addr < BEYOND_CART) {
            return self.mbc.get(@intCast(u15, addr));
        }

        const raw = @ptrCast([*]u8, &self.dyn);
        return raw[addr - BEYOND_CART];
    }

    fn set(self: *Mmu, addr: u16, val: u8) void {
        if (addr < BEYOND_CART) {
            return self.mbc.set(@intCast(u15, addr), val);
        }

        const raw = @ptrCast([*]u8, &self.dyn);
        raw[addr - BEYOND_CART] = val;

        // TODO: replace magic with sibling references
        const fd = @fieldParentPtr(main.Fundude, "mmu", self);

        switch (addr) {
            0x8000...0x9FFF => fd.video.updatedVram(self, addr, val),
            0xC000...0xDDFF => self.dyn.ram[addr - 0xC000] = val, // Echo of 8kB Internal RAM
            0xE000...0xFDFF => self.dyn.ram[addr - 0xE000] = val, // Echo of 8kB Internal RAM
            0xFE00...0xFE9F => fd.video.updatedOam(self, addr, val),
            0xFF00 => fd.inputs.sync(self),
            0xFF40...0xFF4B => fd.video.updatedIo(self, addr, val),
            else => {},
        }
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
