const std = @import("std");
const main = @import("main.zig");
const Matrix = @import("util.zig").Matrix;
const MatrixSlice = @import("util.zig").MatrixSlice;
const EnumArray = @import("util.zig").EnumArray;

const SCREEN_WIDTH = 160;
const SCREEN_HEIGHT = 144;
const DOTS_PER_LINE = 456;
const BUFFER_LINES = 10;
const DOTS_PER_FRAME = (SCREEN_HEIGHT + BUFFER_LINES) * DOTS_PER_LINE;

pub const Io = packed struct {
    LCDC: packed struct {
        bg_enable: bool,
        obj_enable: bool,
        obj_size: enum(u1) {
            Small = 0,
            Large = 1,
        },
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

const Shade = enum(u8) {
    White = 0,
    Light = 1,
    Dark = 2,
    Black = 3,

    fn asOpaque(self: Shade) Pixel {
        const value: u5 = switch (self) {
            .White => 31,
            .Light => 21,
            .Dark => 11,
            .Black => 0,
        };
        return .{
            .r = value,
            .g = value,
            .b = value,
            .opaque = true,
        };
    }

    fn asPixel(self: Shade) Pixel {
        var result = self.asOpaque();
        result.opaque = self != .White;
        return result;
    }
};

const Pixel = packed struct {
    r: u5,
    g: u5,
    b: u5,
    opaque: bool,
};

const ColorPalette = packed struct {
    _: u8,

    fn lookup(self: ColorPalette) EnumArray(Color, Shade) {
        var result: EnumArray(Color, Shade) = undefined;
        result.set(._0, @intToEnum(Shade, self._ >> (0 * 2) & 0b11));
        result.set(._1, @intToEnum(Shade, self._ >> (1 * 2) & 0b11));
        result.set(._2, @intToEnum(Shade, self._ >> (2 * 2) & 0b11));
        result.set(._3, @intToEnum(Shade, self._ >> (3 * 2) & 0b11));
        return result;
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
                ._9800 => self._9800.toSlice(),
                ._9C00 => self._9C00.toSlice(),
            };
        }
    },
};

pub const Video = struct {
    buffer0: Matrix(Pixel, SCREEN_WIDTH, SCREEN_HEIGHT),
    buffer1: Matrix(Pixel, SCREEN_WIDTH, SCREEN_HEIGHT),

    screen: MatrixSlice(Pixel),
    draw: MatrixSlice(Pixel),

    clock: u32,
    cache: struct {
        const CachedPattern = Matrix(Color, 8, 8);

        const TilesCache = struct {
            data: Matrix(Pixel, 256, 256),
            dirty: bool,

            fn run(self: *@This(), mmu: *main.Mmu, patternsData: []CachedPattern, tile_map_addr: TileMapAddressing) void {
                if (!self.dirty) return;
                self.dirty = false;

                const tile_map = mmu.dyn.vram.tile_maps.get(tile_map_addr);
                const tile_addressing = mmu.dyn.io.video.LCDC.bg_window_tile_data;
                const palette = mmu.dyn.io.video.BGP.lookup();

                // O(n^4)...
                var i: u16 = 0;
                while (i < tile_map.width) : (i += 1) {
                    var j: u16 = 0;
                    while (j < tile_map.height) : (j += 1) {
                        const idx = tile_addressing.translate(tile_map.get(i, j));
                        const pattern = patternsData[idx];

                        var x: usize = 0;
                        while (x < pattern.width) : (x += 1) {
                            const xbg = x + i * pattern.width;

                            var y: usize = 0;
                            while (y < pattern.height) : (y += 1) {
                                const ybg = y + j * pattern.height;
                                const color = pattern.get(x, y);
                                const shade = palette.get(color);
                                self.data.set(xbg, ybg, shade.asPixel());
                            }
                        }
                    }
                }
            }
        };

        patterns: struct {
            data: [3 * 128]CachedPattern,
            dirty: bool,

            // TODO: this is pretty brutal
            fn toMatrixSlice(self: *@This()) MatrixSlice(u8) {
                return .{
                    .data = std.mem.asBytes(&self.data),
                    .width = CachedPattern.width,
                    .height = CachedPattern.height * self.data.len,
                };
            }

            fn run(self: *@This(), mmu: *main.Mmu) void {
                if (!self.dirty) return;
                self.dirty = false;

                for (mmu.dyn.vram.patterns) |raw_pattern, i| {
                    var patterns = &self.data[i];

                    var y: usize = 0;
                    while (y < patterns.height) : (y += 1) {
                        const line = raw_pattern._[y];

                        var x: usize = 0;
                        while (x < patterns.width) : (x += 1) {
                            const bit = @intCast(u4, patterns.width - x - 1);
                            const hi = @intCast(u2, line >> bit & 1);
                            const lo = @intCast(u2, line >> (bit + 8) & 1);
                            patterns.set(x, y, @intToEnum(Color, hi << 1 | lo));
                        }
                    }
                }
            }
        },
        sprites: struct {
            const SpriteMeta = extern struct {
                in_front: bool = true,
            };

            data: Matrix(Pixel, 256 + 2 * 8, 256 + 2 * 16),
            meta: Matrix(SpriteMeta, 256 + 2 * 8, 256 + 2 * 16),
            dirty: bool,

            fn oamLessThan(lhs: SpriteAttr, rhs: SpriteAttr) bool {
                return lhs.x_pos > rhs.x_pos;
            }

            fn run(self: *@This(), mmu: *main.Mmu, patternsData: []CachedPattern) void {
                if (!self.dirty) return;
                self.dirty = false;

                self.data.reset(Shade.White.asPixel());
                self.meta.reset(.{});

                var sorted = mmu.dyn.oam;
                std.sort.sort(SpriteAttr, &sorted, oamLessThan);
                // Lower == higher priority, so we need to iterate backwards for painters algorithm
                // TODO: ignore sprites > 10
                std.mem.reverse(SpriteAttr, &sorted);

                const obp0 = mmu.dyn.io.video.OBP0.lookup();
                const obp1 = mmu.dyn.io.video.OBP1.lookup();

                const mask: u8 = switch (mmu.dyn.io.video.LCDC.obj_size) {
                    .Small => 0xFF,
                    .Large => 0xFE,
                };
                const height: usize = switch (mmu.dyn.io.video.LCDC.obj_size) {
                    .Small => 8,
                    .Large => 16,
                };

                for (sorted) |sprite_attr, i| {
                    const palette = switch (sprite_attr.flags.palette) {
                        .OBP0 => obp0,
                        .OBP1 => obp1,
                    };

                    const pattern0 = patternsData[sprite_attr.pattern & mask];
                    const pattern1 = patternsData[sprite_attr.pattern | ~mask];

                    var x: usize = 0;
                    while (x < pattern0.width) : (x += 1) {
                        const xs = sprite_attr.x_pos +
                            if (sprite_attr.flags.x_flip) pattern0.width - x - 1 else x;

                        var y: usize = 0;
                        while (y < height) : (y += 1) {
                            const ys = sprite_attr.y_pos +
                                if (sprite_attr.flags.y_flip) height - y - 1 else y;

                            const color = if (y < pattern0.height)
                                pattern0.get(x, y)
                            else
                                pattern1.get(x, y - pattern0.height);

                            if (color != ._0) {
                                const shade = palette.get(color);
                                self.data.set(xs, ys, shade.asOpaque());
                                self.meta.set(xs, ys, .{
                                    // TODO: why was this redundant check here?
                                    // .opaque = color != ._0,
                                    .in_front = !sprite_attr.flags.priority,
                                });
                            }
                        }
                    }
                }
            }
        },
        background: TilesCache,
        window: TilesCache,
    },

    pub fn reset(self: *Video) void {
        self.buffer0.reset(Shade.White.asPixel());
        self.screen = self.buffer0.toSlice();
        self.draw = self.buffer1.toSlice();
        self.clock = 0;

        self.cache.patterns.dirty = true;
        self.cache.sprites.dirty = true;
        self.cache.window.dirty = true;
        self.cache.background.dirty = true;
    }

    pub fn updatedVram(self: *Video, mmu: *main.Mmu, addr: u16, val: u8) void {
        self.cache.patterns.dirty = true;
        self.cache.window.dirty = true;
        self.cache.background.dirty = true;

        if (addr < 0x9800) {
            self.cache.sprites.dirty = true;
        }
    }

    pub fn updatedOam(self: *Video, mmu: *main.Mmu, addr: u16, val: u8) void {
        self.cache.sprites.dirty = true;
    }

    pub fn updatedIo(self: *Video, mmu: *main.Mmu, addr: u16, val: u8) void {
        switch (addr) {
            0xFF40, 0xFF47 => {
                self.cache.window.dirty = true;
                self.cache.background.dirty = true;
            },
            0xFF46, 0xFF48, 0xFF49 => self.cache.sprites.dirty = true,
            else => {},
        }
    }

    pub fn step(self: *Video, mmu: *main.Mmu, cycles: u16) void {
        // FIXME: this isn't how DMA works
        if (mmu.dyn.io.video.DMA != 0) {
            const addr = @intCast(u16, mmu.dyn.io.video.DMA) << 8;
            const oam = @ptrCast([*]u8, &mmu.dyn.oam);
            std.mem.copy(u8, oam[0..160], mmu.ptr(addr)[0..160]);
            mmu.dyn.io.video.DMA = 0;
        }

        if (!mmu.dyn.io.video.LCDC.lcd_enable) {
            if (self.clock != 0) {
                self.buffer0.reset(Shade.White.asPixel());
                self.screen = self.buffer0.toSlice();
                self.draw = self.buffer1.toSlice();
                self.clock = 0;

                mmu.dyn.io.video.STAT.mode = .hblank;
            }
            return;
        }

        self.clock += cycles;

        if (self.clock > DOTS_PER_FRAME) {
            self.clock -= DOTS_PER_FRAME;
        }

        const line_num = self.clock / DOTS_PER_LINE;
        if (mmu.dyn.io.video.LY != line_num) {
            mmu.dyn.io.video.LY = @intCast(u8, line_num);
            mmu.dyn.io.video.STAT.coincidence = line_num == mmu.dyn.io.video.LYC;

            if (mmu.dyn.io.video.STAT.irq_coincidence and mmu.dyn.io.video.STAT.coincidence) {
                mmu.dyn.io.IF.lcd_stat = true;
            }
        }

        const new_mode: LcdcMode = if (line_num >= SCREEN_HEIGHT)
            .vblank
        else
            @as(LcdcMode, switch (self.clock % DOTS_PER_LINE) {
                0...79 => .searching,
                80...291 => .transferring,
                else => .hblank,
            });

        if (mmu.dyn.io.video.STAT.mode == new_mode) {
            return;
        }
        mmu.dyn.io.video.STAT.mode = new_mode;

        switch (new_mode) {
            .searching => {
                // TODO: ready the pixel gun here and draw the dots across .transferring
                self.render(mmu, line_num);
                if (mmu.dyn.io.video.STAT.irq_oam) {
                    mmu.dyn.io.IF.lcd_stat = true;
                }
            },
            .transferring => {},
            .hblank => {
                if (mmu.dyn.io.video.STAT.irq_hblank) {
                    mmu.dyn.io.IF.lcd_stat = true;
                }
            },
            .vblank => {
                std.mem.swap(MatrixSlice(Pixel), &self.screen, &self.draw);

                mmu.dyn.io.IF.vblank = true;
                if (mmu.dyn.io.video.STAT.irq_vblank) {
                    mmu.dyn.io.IF.lcd_stat = true;
                }
            },
        }
    }

    // TODO: audit this function
    fn render(self: *Video, mmu: *main.Mmu, y: usize) void {
        self.cache.patterns.run(mmu);
        self.cache.sprites.run(mmu, &self.cache.patterns.data);
        self.cache.background.run(mmu, &self.cache.patterns.data, mmu.dyn.io.video.LCDC.bg_tile_map);
        self.cache.window.run(mmu, &self.cache.patterns.data, mmu.dyn.io.video.LCDC.window_tile_map);

        const line = self.draw.sliceLine(0, y);

        if (mmu.dyn.io.video.LCDC.bg_enable) {
            const xbg = mmu.dyn.io.video.SCX % self.cache.background.data.width;
            const ybg = (mmu.dyn.io.video.SCY + y) % self.cache.background.data.height;

            const bg_start = self.cache.background.data.sliceLine(xbg, ybg);
            std.mem.copy(Pixel, line, bg_start[0..std.math.min(bg_start.len, line.len)]);

            if (line.len > bg_start.len) {
                const bg_rest = self.cache.background.data.sliceLine(0, ybg);
                std.mem.copy(Pixel, line[bg_start.len..], bg_rest[0 .. line.len - bg_start.len]);
            }
        } else {
            std.mem.set(Pixel, line, Shade.White.asPixel());
        }

        const xw = mmu.dyn.io.video.WX -% 7;
        const yw = y -% mmu.dyn.io.video.WY;
        if (mmu.dyn.io.video.LCDC.window_enable and xw < self.cache.window.data.width and yw < self.cache.window.data.height) {
            const win = self.cache.window.data.sliceLine(0, yw);
            std.mem.copy(Pixel, line[xw..], win[0 .. line.len - xw]);
        }

        // TODO: vectorize
        if (mmu.dyn.io.video.LCDC.obj_enable) {
            const sprites = self.cache.sprites.data.sliceLine(8, y + 16);
            const metas = self.cache.sprites.meta.sliceLine(8, y + 16);

            for (line) |*pixel, x| {
                if (sprites[x].opaque and (metas[x].in_front or !pixel.opaque)) {
                    pixel.* = sprites[x];
                }
            }
        }
    }
};
