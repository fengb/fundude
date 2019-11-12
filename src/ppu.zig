const std = @import("std");
const base = @import("base.zig");
const Matrix = @import("util.zig").Matrix;
const MatrixSlice = @import("util.zig").MatrixSlice;

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
};

const LcdcMode = enum(u2) {
    hblank = 0,
    vblank = 1,
    searching = 2,
    transferring = 3,
};

const Color = enum(u8) {
    _0 = 0,
    _1 = 1,
    _2 = 2,
    _3 = 3,
};

const ColorPalette = packed struct {
    _: u8,

    pub fn toShade(self: ColorPalette, color: Color) u2 {
        const int = @intCast(u3, @enumToInt(color));
        return @intCast(u2, self._ >> (int * 2) & 0b11);
    }
};

const RawPattern = packed struct {
    _: [8]u16,
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

    pub fn isOffScreen(self: SpriteAttr) bool {
        return self.x_pos == 0 and self.y_pos == 0;
    }
};

const SpritePalette = enum(u1) {
    OBP0 = 0,
    OBP1 = 1,
};

const TileAddressing = enum(u1) {
    _8800 = 0,
    _8000 = 1,

    pub fn translate(self: TileAddressing, idx: u8) u9 {
        return if (idx >= 128 or self == ._8000) idx else idx + @as(u9, 256);
    }
};

const TileMapAddressing = enum(u1) {
    _9800 = 0,
    _9C00 = 1,
};

pub const Vram = packed struct {
    patterns: [3 * 128]RawPattern,

    tile_maps: packed struct {
        _9800: Matrix(u8, 32, 32), // $9800-9BFF
        _9C00: Matrix(u8, 32, 32), // $9C00-9FFF

        pub fn get(self: *@This(), addressing: TileMapAddressing) MatrixSlice(u8) {
            return switch (addressing) {
                ._9800 => self._9800.slice(),
                ._9C00 => self._9C00.slice(),
            };
        }
    },
};

pub const Ppu = struct {
    screen: Matrix(u8, SCREEN_WIDTH, SCREEN_HEIGHT),

    patterns: [3 * 128]Matrix(Color, 8, 8),

    spritesheet: [40]Matrix(u8, 8, 8),
    background: Matrix(u8, 256, 256),
    window: Matrix(u8, 256, 256),

    clock: u32,
    dirtyPatterns: bool,
    dirtyBackground: bool,
    dirtySpritesheet: bool,

    pub fn reset(self: *Ppu) void {
        self.clock = 0;
        self.dirtyPatterns = true;
        self.dirtyBackground = true;
        self.dirtySpritesheet = true;

        self.screen.reset(0);
        for (self.patterns) |*patterns| {
            patterns.reset(._0);
        }
        for (self.spritesheet) |*sprite| {
            sprite.reset(0);
        }
        self.background.reset(0);
        self.window.reset(0);
    }

    pub fn updatedVram(self: *Ppu, mmu: *base.Mmu, addr: u16, val: u8) void {
        if (addr < 0x9800) {
            self.dirtyPatterns = true;
            self.dirtyBackground = true;
            self.dirtySpritesheet = true;
        } else {
            self.dirtyBackground = true;
        }
    }

    pub fn updatedOam(self: *Ppu, mmu: *base.Mmu, addr: u16, val: u8) void {
        self.dirtySpritesheet = true;
    }

    pub fn updatedIo(self: *Ppu, mmu: *base.Mmu, addr: u16, val: u8) void {
        switch (addr) {
            0xFF40, 0xFF47 => self.dirtyBackground = true,
            0xFF46, 0xFF48, 0xFF49 => self.dirtySpritesheet = true,
            else => {},
        }
    }

    pub fn step(self: *Ppu, mmu: *base.Mmu, cycles: u16) void {
        // FIXME: this isn't how DMA works
        if (mmu.dyn.io.ppu.DMA != 0) {
            const addr = @intCast(u16, mmu.dyn.io.ppu.DMA) << 8;
            const oam = @ptrCast([*]u8, &mmu.dyn.oam);
            std.mem.copy(u8, oam[0..160], mmu.ptr(addr)[0..160]);
            mmu.dyn.io.ppu.DMA = 0;
        }

        if (!mmu.dyn.io.ppu.LCDC.lcd_enable) {
            self.clock = 0;
            mmu.dyn.io.ppu.STAT.mode = .hblank;
            return;
        }

        self.clock += cycles;

        while (self.clock > DOTS_PER_FRAME) : (self.clock -= DOTS_PER_FRAME) {}

        const new_ly = self.clock / DOTS_PER_LINE;
        if (mmu.dyn.io.ppu.LY != new_ly) {
            mmu.dyn.io.ppu.LY = @intCast(u8, new_ly);
            mmu.dyn.io.ppu.STAT.coincidence = new_ly == mmu.dyn.io.ppu.LYC;
        }

        if ((mmu.dyn.io.ppu.STAT.irq_coincidence and mmu.dyn.io.ppu.STAT.coincidence) or
            (mmu.dyn.io.ppu.STAT.irq_hblank and mmu.dyn.io.ppu.STAT.mode == .hblank) or
            (mmu.dyn.io.ppu.STAT.irq_vblank and mmu.dyn.io.ppu.STAT.mode == .vblank) or
            (mmu.dyn.io.ppu.STAT.irq_oam and mmu.dyn.io.ppu.STAT.mode == .searching))
        {
            mmu.dyn.io.IF.lcd_stat = true;
        }

        if (self.clock > SCREEN_HEIGHT * DOTS_PER_LINE) {
            // TODO: render specific pixels in mode 3 / transferring
            if (mmu.dyn.io.ppu.STAT.mode != .vblank) {
                mmu.dyn.io.ppu.STAT.mode = .vblank;
                mmu.dyn.io.IF.vblank = true;
                self.render(mmu);
            }
            return;
        }

        const offset = self.clock % DOTS_PER_LINE;
        if (offset < 80) {
            mmu.dyn.io.ppu.STAT.mode = .searching;
        } else if (offset < 291) {
            // TODO: offset depends on sprite
            mmu.dyn.io.ppu.STAT.mode = .transferring;
        } else {
            mmu.dyn.io.ppu.STAT.mode = .hblank;
        }
    }

    fn renderPatterns(self: *Ppu, mmu: *base.Mmu) void {
        for (mmu.dyn.vram.patterns) |raw_pattern, i| {
            var patterns = &self.patterns[i];

            var y: usize = 0;
            while (y < patterns.height()) : (y += 1) {
                const line = raw_pattern._[y];

                var x: usize = 0;
                while (x < patterns.width()) : (x += 1) {
                    const bit = @intCast(u4, patterns.width() - x - 1);
                    const hi = @intCast(u2, line >> bit & 1);
                    const lo = @intCast(u2, line >> (bit + 8) & 1);
                    patterns.set(x, y, @intToEnum(Color, hi << 1 | lo));
                }
            }
        }
    }

    fn renderBg(self: *Ppu, mmu: *base.Mmu, matrix: MatrixSlice(u8), tile_map_addr: TileMapAddressing) void {
        const tile_map = mmu.dyn.vram.tile_maps.get(tile_map_addr);
        const tile_addressing = mmu.dyn.io.ppu.LCDC.bg_window_tile_data;
        const palette = mmu.dyn.io.ppu.BGP;

        // O(n^4)...
        var i: u16 = 0;
        while (i < tile_map.width) : (i += 1) {
            var j: u16 = 0;
            while (j < tile_map.height) : (j += 1) {
                const idx = tile_addressing.translate(tile_map.get(i, j));
                const pattern = self.patterns[idx];

                var x: usize = 0;
                while (x < pattern.width()) : (x += 1) {
                    const xbg = x + i * pattern.width();

                    var y: usize = 0;
                    while (y < pattern.height()) : (y += 1) {
                        const ybg = y + j * pattern.height();
                        const pixel = pattern.get(x, y);
                        matrix.set(xbg, ybg, palette.toShade(pixel));
                    }
                }
            }
        }
    }

    fn renderSprites(self: *Ppu, mmu: *base.Mmu) void {
        for (mmu.dyn.oam) |sprite_attr, i| {
            if (sprite_attr.isOffScreen() and sprite_attr.pattern == 0) {
                continue;
            }

            const palette = switch (sprite_attr.flags.palette) {
                .OBP0 => mmu.dyn.io.ppu.OBP0,
                .OBP1 => mmu.dyn.io.ppu.OBP1,
            };

            const sprite = &self.spritesheet[i];
            const pattern = self.patterns[sprite_attr.pattern];

            var x: usize = 0;
            while (x < pattern.width()) : (x += 1) {
                const xs = if (sprite_attr.flags.x_flip) pattern.width() - x - 1 else x;

                var y: usize = 0;
                while (y < pattern.height()) : (y += 1) {
                    const ys = if (sprite_attr.flags.y_flip) pattern.width() - y - 1 else y;

                    const pixel = palette.toShade(pattern.get(x, y));
                    sprite.set(xs, ys, pixel);
                }
            }
        }
    }

    // TODO: audit this function
    fn render(self: *Ppu, mmu: *base.Mmu) void {
        if (self.dirtyPatterns) {
            self.renderPatterns(mmu);
            self.dirtyPatterns = false;
        }

        if (self.dirtySpritesheet) {
            self.renderSprites(mmu);
            self.dirtySpritesheet = false;
        }

        if (self.dirtyBackground) {
            self.renderBg(mmu, self.background.slice(), mmu.dyn.io.ppu.LCDC.bg_tile_map);
            self.renderBg(mmu, self.window.slice(), mmu.dyn.io.ppu.LCDC.window_tile_map);
            self.dirtyBackground = false;
        }

        if (mmu.dyn.io.ppu.LCDC.bg_enable) {
            const scx = mmu.dyn.io.ppu.SCX;
            const scy = mmu.dyn.io.ppu.SCY;

            var x: usize = 0;
            while (x < SCREEN_WIDTH) : (x += 1) {
                const xbg = (scx + x) % self.background.width();

                var y: usize = 0;
                while (y < SCREEN_HEIGHT) : (y += 1) {
                    const ybg = (scy + y) % self.background.height();

                    const pixel = self.background.get(xbg, ybg);
                    self.screen.set(x, y, pixel);
                }
            }
        }

        if (mmu.dyn.io.ppu.LCDC.window_enable) {
            const wx = mmu.dyn.io.ppu.WX;
            const wy = mmu.dyn.io.ppu.WY;

            var x: usize = 0;
            while (x < SCREEN_WIDTH) : (x += 1) {
                const xw = x -% (mmu.dyn.io.ppu.WX -% 7);
                if (xw >= self.window.width()) {
                    continue;
                }

                var y: usize = 0;
                while (y < SCREEN_HEIGHT) : (y += 1) {
                    const yw = y -% mmu.dyn.io.ppu.WY;
                    if (yw >= self.window.height()) {
                        continue;
                    }

                    const pixel = self.window.get(xw, yw);
                    self.screen.set(x, y, pixel);
                }
            }
        }

        // TODO: this is ugly but it'll be completely replaced by pixel-by-pixel
        for (mmu.dyn.oam) |sprite_attr, i| {
            if (sprite_attr.isOffScreen()) {
                continue;
            }

            const sprite = self.spritesheet[i];

            var x: usize = 0;
            while (x < sprite.width()) : (x += 1) {
                const xs = sprite_attr.x_pos + x -% 8;
                if (xs >= self.screen.width()) {
                    continue;
                }

                var y: usize = 0;
                while (y < sprite.height()) : (y += 1) {
                    const ys = sprite_attr.y_pos + y -% 16;
                    if (ys >= self.screen.height()) {
                        continue;
                    }

                    self.screen.set(xs, ys, sprite.get(x, y));
                }
            }
        }
    }
};
