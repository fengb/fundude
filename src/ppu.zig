const std = @import("std");
const base = @import("base.zig");
const Matrix = @import("util.zig").Matrix;
const MatrixSlice = @import("util.zig").MatrixSlice;

const BG_TILES = (32 * 32);
const SCREEN_WIDTH = 160;
const SCREEN_HEIGHT = 144;
const DOTS_PER_LINE = 456;
const BUFFER_LINES = 10;
const DOTS_PER_FRAME = (SCREEN_HEIGHT + BUFFER_LINES) * DOTS_PER_LINE;

pub const Io = packed struct {
    LCDC: packed struct {
        bg_enable: bool,
        obj_enable: bool,
        obj_size: u1,
        bg_tile_map: TileMapAddressing,
        bg_window_tile_data: TileAddressing,
        window_enable: bool,
        window_tile_map: TileMapAddressing,
        lcd_enable: bool,
    },
    STAT: packed struct {
        mode: LcdcMode,
        coincidence: bool,
        irq_hblank: bool,
        irq_vblank: bool,
        irq_oam: bool,
        irq_coincidence: bool,
        _pad: u1,
    },
    SCY: u8, // $FF42
    SCX: u8, // $FF43
    LY: u8, // $FF44
    LYC: u8, // $FF45
    DMA: u8, // $FF46
    BGP: ColorPalette, // $FF47
    OBP0: ColorPalette, // $FF48
    OBP1: ColorPalette, // $FF49
    WY: u8, // $FF4A
    WX: u8, // $FF4B

    fn spritePalette(self: Io, selection: SpritePalette) ColorPalette {
        return switch (selection) {
            .OBP0 => self.OBP0,
            .OBP1 => self.OBP1,
        };
    }
};

const LcdcMode = enum(u2) {
    hblank = 0,
    vblank = 1,
    searching = 2,
    transferring = 3,
};

const Color = enum(u2) {
    _0 = 0,
    _1 = 1,
    _2 = 2,
    _3 = 3,

    pub fn init(val: u16, bit: u4) Color {
        const hi = @intCast(u2, val >> bit & 1);
        const lo = @intCast(u2, val >> (bit + 8) & 1);
        return @intToEnum(Color, hi << 1 | lo);
    }
};

const ColorPalette = packed struct {
    _: u8,

    pub fn none() ColorPalette {
        return ColorPalette{ ._ = 0b11100100 };
    }

    pub fn toShade(self: ColorPalette, color: Color) u2 {
        const int = @intCast(u3, @enumToInt(color));
        return @intCast(u2, self._ >> (int * 2) & 0b11);
    }
};

test "ColorPalette" {
    const pal = ColorPalette.none();
    std.debug.warn("{} {} {} {}\n", pal.toShade(._0), pal.toShade(._1), pal.toShade(._2), pal.toShade(._3));
}

const Pattern = packed struct {
    _: [8]u16,

    pub fn pixelSize() comptime_int {
        return 8;
    }
};

const PatternMap = packed struct {
    _: [BG_TILES]u8,
};

pub const SpriteAttr = packed struct {
    y_pos: u8,
    x_pos: u8,
    pattern: u8,
    flags: packed struct {
        _pad: u4,
        palette: SpritePalette,
        x_flip: bool,
        y_flip: bool,
        priority: bool,
    },

    pub fn isBlank(self: SpriteAttr) bool {
        return self.x_pos == 0 and self.y_pos == 0 and self.pattern == 0;
    }
};

const SpritePalette = enum(u1) {
    OBP0 = 0,
    OBP1 = 1,
};

const TileAddressing = enum(u1) {
    _8800 = 0,
    _8000 = 1,
};

const TileMapAddressing = enum(u1) {
    _9800 = 0,
    _9C00 = 1,
};

pub const Vram = packed struct {
    patterns: packed struct {
        _8000: [128]Pattern, // $8000-87FF
        _8800: [128]Pattern, // $8800-8FFF
        _9000: [128]Pattern, // $9000-97FF

        pub fn all(self: *@This()) []Pattern {
            const ptr = @ptrCast([*]Pattern, self);
            return ptr[0..(128 * 3)];
        }

        pub fn get(self: @This(), addressing: TileAddressing, idx: u8) Pattern {
            if (idx >= 128) {
                return self._8800[idx - 128];
            } else if (addressing == ._8000) {
                return self._8000[idx];
            } else {
                return self._9000[idx];
            }
        }
    },

    tile_maps: packed struct {
        _9800: PatternMap, // $9800-9BFF
        _9C00: PatternMap, // $9C00-9FFF

        pub fn get(self: @This(), addressing: TileMapAddressing) PatternMap {
            return switch (addressing) {
                ._9800 => self._9800,
                ._9C00 => self._9C00,
            };
        }
    },
};

pub const Ppu = struct {
    screen: Matrix(u8, SCREEN_WIDTH, SCREEN_HEIGHT),

    patterns: Matrix(u8, 192, 128),
    sprites: Matrix(u8, 160, 32),
    background: Matrix(u8, 256, 256),
    window: Matrix(u8, 256, 256),

    clock: u32,

    pub fn reset(self: *Ppu) void {
        self.clock = 0;

        self.screen.reset(0);
        self.patterns.reset(0);
        self.sprites.reset(0);
        self.background.reset(0);
        self.window.reset(0);
    }

    pub fn step(self: *Ppu, mmu: *base.Mmu, cycles: u16) void {
        // FIXME: this isn't how DMA works
        if (mmu.io.ppu.DMA != 0) {
            const addr = @intCast(u16, mmu.io.ppu.DMA) << 8;
            const oam = @ptrCast([*]u8, &mmu.oam);
            std.mem.copy(u8, oam[0..160], mmu.ptr(addr)[0..160]);
            mmu.io.ppu.DMA = 0;
        }

        if (!mmu.io.ppu.LCDC.lcd_enable) {
            self.clock = 0;
            mmu.io.ppu.STAT.mode = .hblank;
            return;
        }

        self.clock += cycles;

        while (self.clock > DOTS_PER_FRAME) : (self.clock -= DOTS_PER_FRAME) {}

        const new_ly = self.clock / DOTS_PER_LINE;
        if (mmu.io.ppu.LY != new_ly) {
            mmu.io.ppu.LY = @intCast(u8, new_ly);
            mmu.io.ppu.STAT.coincidence = new_ly == mmu.io.ppu.LYC;
        }

        if ((mmu.io.ppu.STAT.irq_coincidence and mmu.io.ppu.STAT.coincidence) or
            (mmu.io.ppu.STAT.irq_hblank and mmu.io.ppu.STAT.mode == .hblank) or
            (mmu.io.ppu.STAT.irq_vblank and mmu.io.ppu.STAT.mode == .vblank) or
            (mmu.io.ppu.STAT.irq_oam and mmu.io.ppu.STAT.mode == .searching))
        {
            mmu.io.IF.lcd_stat = true;
        }

        if (self.clock > SCREEN_HEIGHT * DOTS_PER_LINE) {
            // TODO: render specific pixels in mode 3 / transferring
            if (mmu.io.ppu.STAT.mode != .vblank) {
                mmu.io.ppu.STAT.mode = .vblank;
                mmu.io.IF.vblank = true;
                self.render(mmu);
            }
            return;
        }

        const offset = self.clock % DOTS_PER_LINE;
        if (offset < 80) {
            mmu.io.ppu.STAT.mode = .searching;
        } else if (offset < 291) {
            // TODO: offset depends on sprite
            mmu.io.ppu.STAT.mode = .transferring;
        } else {
            mmu.io.ppu.STAT.mode = .hblank;
        }
    }

    fn render(self: *Ppu, mmu: *base.Mmu) void {
        for (mmu.vram.patterns.all()) |pattern, i| {
            drawPattern(self.patterns.slice, i, pattern, ColorPalette.none());
        }

        renderBg(mmu, self.background.slice, mmu.io.ppu.LCDC.bg_tile_map);
        renderBg(mmu, self.window.slice, mmu.io.ppu.LCDC.window_tile_map);

        for (mmu.oam) |sprite_attr, i| {
            if (sprite_attr.isBlank()) {
                continue;
            }

            const pattern = mmu.vram.patterns.get(._8000, sprite_attr.pattern);
            const palette = mmu.io.ppu.spritePalette(sprite_attr.flags.palette);

            drawPattern(self.sprites.slice, i, pattern, palette);
        }

        // TODO: use memcpy
        if (mmu.io.ppu.LCDC.bg_enable) {
            const scx = mmu.io.ppu.SCX;
            const scy = mmu.io.ppu.SCY;

            var y = usize(0);
            while (y < SCREEN_HEIGHT) : (y += 1) {
                var x = usize(0);
                while (x < SCREEN_HEIGHT) : (x += 1) {
                    const pixel = self.background.get((scx + x) % self.background.width(), (scy + y) % self.background.height());
                    self.screen.set(x, y, pixel);
                }
            }
        }

        if (mmu.io.ppu.LCDC.window_enable) {
            const wx = mmu.io.ppu.WX;
            const wy = mmu.io.ppu.WY;

            var y = usize(0);
            while (y < SCREEN_HEIGHT) : (y += 1) {
                var x = usize(0);
                while (x < SCREEN_WIDTH) : (x += 1) {
                    const pixel = self.window.get(x - (wx - 7), wy - y);
                    self.screen.set(x, y, pixel);
                }
            }
        }

        for (mmu.oam) |sprite_attr, i| {
            if (sprite_attr.isBlank()) {
                continue;
            }

            const pattern = mmu.vram.patterns.get(._8000, sprite_attr.pattern);
            const palette = mmu.io.ppu.spritePalette(sprite_attr.flags.palette);

            drawPattern(self.sprites.slice, i, pattern, palette);
            drawPatternXy(self.screen.slice, sprite_attr.x_pos - 8, sprite_attr.y_pos - 16, pattern, palette);
        }
    }

    fn renderBg(mmu: *base.Mmu, matrix: MatrixSlice(u8), tile_map_addr: TileMapAddressing) void {
        const tile_map = mmu.vram.tile_maps.get(tile_map_addr);
        const tile_addressing = mmu.io.ppu.LCDC.bg_window_tile_data;

        var i = usize(0);
        while (i < BG_TILES) : (i += 0) {
            const tile = mmu.vram.patterns.get(tile_addressing, @intCast(u8, i));
            drawPattern(matrix, i, tile, mmu.io.ppu.BGP);
        }
    }

    // TODO: refactor all of this
    fn drawPattern(matrix: MatrixSlice(u8), idx: usize, pattern: Pattern, palette: ColorPalette) void {
        const transform = matrix.width / Pattern.pixelSize();
        const tx = idx % transform;
        const ty = idx / transform;
        drawPatternXy(matrix, tx * Pattern.pixelSize(), ty * Pattern.pixelSize(), pattern, palette);
    }

    fn drawPatternXy(matrix: MatrixSlice(u8), x0: usize, y0: usize, pattern: Pattern, palette: ColorPalette) void {
        var py = usize(0);
        while (py < Pattern.pixelSize()) : (py += 1) {
            const line = pattern._[py];

            var px = usize(0);
            while (px < Pattern.pixelSize()) : (px += 1) {
                const color = Color.init(line, @intCast(u4, Pattern.pixelSize() - px - 1));
                const x = x0 + px;
                const y = y0 + py;
                matrix.set(x, y, palette.toShade(color));
            }
        }
    }
};
