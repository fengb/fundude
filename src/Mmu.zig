const std = @import("std");

const Fundude = @import("main.zig");

const Cpu = @import("Cpu.zig");
const joypad = @import("joypad.zig");
const serial = @import("serial.zig");
const timer = @import("timer.zig");
const audio = @import("audio.zig");
const video = @import("video.zig");

const BEYOND_CART = 0x8000;
const BANK_SIZE = 0x4000;

const Mmu = @This();

dyn: extern struct {
    rom: [0x8000]u8 align(8),
    vram: video.Vram, // [$8000 - $A000)
    switchable_ram: [0x2000]u8, // [$A000 - $C000)
    ram: [0x2000]u8, // [$C000 - $E000)
    ram_echo: [0x1E00]u8, // [$E000 - $FE00)
    oam: [40]video.SpriteAttr, // [$FE00 - $FEA0)
    _pad_fea0_ff00: [0x0060]u8, // [$FEA0 - $FF00)
    io: Io, // [$FF00 - $FF80)
    high_ram: [0x007F]u8, // [$FF80 - $FFFF)
    interrupt_enable: Cpu.Irq, // [$FFFF]
},

bootloader: Bootloader,
cart: []const u8,
bank: u9,

cart_meta: struct {
    mbc: Mbc,
    rumble: bool = false,
    timer: bool = false,
    ram: bool = false,
    battery: bool = false,
},

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

test "offsets" {
    const Linear = std.meta.fieldInfo(Mmu, .dyn).field_type;
    try std.testing.expectEqual(0x10000, @sizeOf(Linear));

    try std.testing.expectEqual(0x0000, @byteOffsetOf(Linear, "rom"));
    try std.testing.expectEqual(0x8000, @byteOffsetOf(Linear, "vram"));
    try std.testing.expectEqual(0xA000, @byteOffsetOf(Linear, "switchable_ram"));
    try std.testing.expectEqual(0xC000, @byteOffsetOf(Linear, "ram"));
    try std.testing.expectEqual(0xE000, @byteOffsetOf(Linear, "ram_echo"));
    try std.testing.expectEqual(0xFE00, @byteOffsetOf(Linear, "oam"));
    try std.testing.expectEqual(0xFF00, @byteOffsetOf(Linear, "io"));
    try std.testing.expectEqual(0xFF80, @byteOffsetOf(Linear, "high_ram"));
    try std.testing.expectEqual(0xFFFF, @byteOffsetOf(Linear, "interrupt_enable"));
}

fn ptrOffsetOf(ref: anytype, target: anytype) usize {
    return @ptrToInt(target) - @ptrToInt(ref);
}

test "Io offsets" {
    var mmu: Mmu = undefined;
    try std.testing.expectEqual(@as(usize, 0xFF04), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.timer));
    try std.testing.expectEqual(@as(usize, 0xFF0F), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.IF));

    try std.testing.expectEqual(@as(usize, 0xFF10), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.audio.NR10));
    try std.testing.expectEqual(@as(usize, 0xFF1E), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.audio.NR34));
    try std.testing.expectEqual(@as(usize, 0xFF20), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.audio.NR41));
    try std.testing.expectEqual(@as(usize, 0xFF26), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.audio.NR52));
    try std.testing.expectEqual(@as(usize, 0xFF30), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.audio.wave_pattern));

    try std.testing.expectEqual(@as(usize, 0xFF40), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.video.LCDC));
    try std.testing.expectEqual(@as(usize, 0xFF49), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.video.OBP1));
    try std.testing.expectEqual(@as(usize, 0xFF4A), ptrOffsetOf(&mmu.dyn, &mmu.dyn.io.video.WY));
}

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
    None,
    Mbc1,
    Mbc3,
    Mbc5,
};

pub fn reset(self: *Mmu) void {
    // @memset(@ptrCast([*]u8, &self.io), 0, @sizeOf(@typeOf(self.io)));
    @memset(@ptrCast([*]u8, &self.dyn.vram), 0, 0x8000);
}

pub fn load(self: *Mmu, cart: []const u8) CartHeaderError!void {
    const size = try RomSize.init(cart[0x148]);
    if (cart.len != size.bytes()) {
        return error.RomSizeError;
    }

    self.cart_meta = switch (cart[0x147]) {
        0x00 => .{ .mbc = .None },
        0x01 => .{ .mbc = .Mbc1 },
        0x02 => .{ .mbc = .Mbc1, .ram = true },
        0x03 => .{ .mbc = .Mbc1, .ram = true, .battery = true },
        0x0F => .{ .mbc = .Mbc3, .timer = true, .battery = true },
        0x10 => .{ .mbc = .Mbc3, .timer = true, .ram = true, .battery = true },
        0x11 => .{ .mbc = .Mbc3 },
        0x12 => .{ .mbc = .Mbc3, .ram = true },
        0x13 => .{ .mbc = .Mbc3, .ram = true, .battery = true },
        0x19 => .{ .mbc = .Mbc5 },
        0x1A => .{ .mbc = .Mbc5, .ram = true },
        0x1B => .{ .mbc = .Mbc5, .ram = true, .battery = true },
        0x1C => .{ .mbc = .Mbc5, .rumble = true },
        0x1D => .{ .mbc = .Mbc5, .rumble = true, .ram = true },
        0x1E => .{ .mbc = .Mbc5, .rumble = true, .ram = true, .battery = true },
        else => return error.CartTypeError,
    };

    // TODO: validate RAM

    self.cart = cart;
    self.bank = 1;
    std.mem.copy(u8, &self.dyn.rom, self.bootloader.rom());
    std.mem.copy(u8, self.dyn.rom[Bootloader.len..], cart[Bootloader.len..0x8000]);
}

pub fn instrBytes(self: Mmu, addr: u16) [3]u8 {
    return std.mem.asBytes(&self.dyn)[addr..][0..3].*;
}

pub fn get(self: Mmu, addr: u16) u8 {
    return std.mem.asBytes(&self.dyn)[addr];
}

pub fn set(self: *Mmu, addr: u16, val: u8) void {
    if (addr < BEYOND_CART) {
        return @call(Fundude.profiling_call, self.setRom, .{ @intCast(u15, addr), val });
    }

    const bytes = std.mem.asBytes(&self.dyn);
    const old = bytes[addr];
    if (old == val) return;
    bytes[addr] = val;

    // TODO: replace magic with sibling references
    const fd = @fieldParentPtr(Fundude, "mmu", self);

    switch (addr) {
        0x8000...0xA000 - 1 => fd.video.updatedVram(self, addr, val),
        0xC000...0xDE00 - 1 => self.dyn.ram_echo[addr - 0xC000] = val, // Echo of 8kB Internal RAM
        0xE000...0xFE00 - 1 => self.dyn.ram[addr - 0xE000] = val, // Echo of 8kB Internal RAM
        0xFE00...0xFEA0 - 1 => fd.video.updatedOam(self, addr, val),
        0xFF00 => fd.inputs.sync(self),
        0xFF40...0xFF4C - 1 => fd.video.updatedIo(self, addr, val),
        0xFF50 => std.mem.copy(u8, &self.dyn.rom, self.cart[0..Bootloader.len]),
        else => {},
    }
}

test "RAM echo" {
    var mmu: Mmu = undefined;
    mmu.set(0xC000, 'A');
    try std.testing.expectEqual(@as(u8, 'A'), mmu.get(0xE000));

    mmu.set(0xC000, 'z');
    try std.testing.expectEqual(@as(u8, 'z'), mmu.get(0xE000));

    mmu.set(0xC777, '?');
    try std.testing.expectEqual(@as(u8, '?'), mmu.get(0xE777));

    // Don't echo OAM
    mmu.set(0xFE00, 69);
    mmu.set(0xDE00, 123);
    try std.testing.expectEqual(@as(u8, 69), mmu.get(0xFE00));
}

// TODO: RAM banking
fn setRom(self: *Mmu, addr: u15, val: u8) void {
    switch (self.cart_meta.mbc) {
        .None => {},
        .Mbc1 => {
            switch (addr) {
                0x0000...0x1FFF => {}, // RAM enable
                0x2000...0x3FFF => {
                    var bank = val & 0x7F;
                    if (bank % 0x20 == 0) {
                        bank += 1;
                    }
                    self.selectRomBank(bank);
                },
                0x4000...0x5FFF => {}, // RAM bank
                0x6000...0x7FFF => {}, // ROM/RAM Mode Select
            }
        },
        .Mbc3 => {
            switch (addr) {
                0x0000...0x1FFF => {}, // RAM/Timer enable
                0x2000...0x3FFF => {
                    const bank = std.math.max(1, val & 0x7F);
                    self.selectRomBank(bank);
                },
                0x4000...0x5FFF => {}, // RAM bank
                0x6000...0x7FFF => {}, // Latch clock
            }
        },
        .Mbc5 => {
            switch (addr) {
                0x0000...0x1FFF => {}, // RAM enable
                0x2000...0x2FFF => {
                    const mask = @as(u9, 1) << 8;
                    const bank = (self.bank & mask) | val;
                    self.selectRomBank(bank);
                },
                0x3000...0x3FFF => {
                    const mask = @as(u9, 1) << 8;
                    const bank = (@as(u9, val) << 8) | (self.bank & ~mask);
                    self.selectRomBank(bank);
                },
                0x4000...0x5FFF => {}, // RAM bank
                0x6000...0x7FFF => {}, // Latch clock
            }
        },
    }
}

fn selectRomBank(self: *Mmu, bank: u9) void {
    const total_banks = self.cart.len / BANK_SIZE;
    const target = std.math.min(bank, total_banks);
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

pub const Bootloader = union(enum) {
    dmg: void,
    mini: void,
    custom: *const [len]u8,

    fn rom(self: Bootloader) *const [len]u8 {
        return switch (self) {
            .dmg => dmg,
            .mini => mini,
            .custom => |custom| custom,
        };
    }

    const len = 0x100;
    pub const dmg = &[len]u8{
        0x31, 0xFE, 0xFF, 0xAF, 0x21, 0xFF, 0x9F, 0x32, 0xCB, 0x7C, 0x20, 0xFB, 0x21, 0x26, 0xFF, 0x0E,
        0x11, 0x3E, 0x80, 0x32, 0xE2, 0x0C, 0x3E, 0xF3, 0xE2, 0x32, 0x3E, 0x77, 0x77, 0x3E, 0xFC, 0xE0,
        0x47, 0x11, 0x04, 0x01, 0x21, 0x10, 0x80, 0x1A, 0xCD, 0x95, 0x00, 0xCD, 0x96, 0x00, 0x13, 0x7B,
        0xFE, 0x34, 0x20, 0xF3, 0x11, 0xD8, 0x00, 0x06, 0x08, 0x1A, 0x13, 0x22, 0x23, 0x05, 0x20, 0xF9,
        0x3E, 0x19, 0xEA, 0x10, 0x99, 0x21, 0x2F, 0x99, 0x0E, 0x0C, 0x3D, 0x28, 0x08, 0x32, 0x0D, 0x20,
        0xF9, 0x2E, 0x0F, 0x18, 0xF3, 0x67, 0x3E, 0x64, 0x57, 0xE0, 0x42, 0x3E, 0x91, 0xE0, 0x40, 0x04,
        0x1E, 0x02, 0x0E, 0x0C, 0xF0, 0x44, 0xFE, 0x90, 0x20, 0xFA, 0x0D, 0x20, 0xF7, 0x1D, 0x20, 0xF2,
        0x0E, 0x13, 0x24, 0x7C, 0x1E, 0x83, 0xFE, 0x62, 0x28, 0x06, 0x1E, 0xC1, 0xFE, 0x64, 0x20, 0x06,
        0x7B, 0xE2, 0x0C, 0x3E, 0x87, 0xE2, 0xF0, 0x42, 0x90, 0xE0, 0x42, 0x15, 0x20, 0xD2, 0x05, 0x20,
        0x4F, 0x16, 0x20, 0x18, 0xCB, 0x4F, 0x06, 0x04, 0xC5, 0xCB, 0x11, 0x17, 0xC1, 0xCB, 0x11, 0x17,
        0x05, 0x20, 0xF5, 0x22, 0x23, 0x22, 0x23, 0xC9, 0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B,
        0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D, 0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E,
        0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99, 0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC,
        0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E, 0x3C, 0x42, 0xB9, 0xA5, 0xB9, 0xA5, 0x42, 0x3C,
        0x21, 0x04, 0x01, 0x11, 0xA8, 0x00, 0x1A, 0x13, 0xBE, 0x20, 0xFE, 0x23, 0x7D, 0xFE, 0x34, 0x20,
        0xF5, 0x06, 0x19, 0x78, 0x86, 0x23, 0x05, 0x20, 0xFB, 0x86, 0x20, 0xFE, 0x3E, 0x01, 0xE0, 0x50,
    };

    pub const mini = &[len]u8{
        0xF3, 0xAF, 0xE0, 0x40, 0xE0, 0x26, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3E, 0x01, 0xE0, 0x50,
    };
};
