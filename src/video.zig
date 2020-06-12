const std = @import("std");
const main = @import("main.zig");
const Matrix = @import("util.zig").Matrix;
const MatrixSlice = @import("util.zig").MatrixSlice;
const EnumArray = @import("util.zig").EnumArray;

const SCREEN_WIDTH = 160;
const SCREEN_HEIGHT = 144;
const DOTS_PER_LINE = 456;
const BUFFER_LINES = 10;
const RENDER_LINES = SCREEN_HEIGHT + BUFFER_LINES;
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

const LcdcMode = packed enum(u2) {
    hblank = 0,
    vblank = 1,
    searching = 2,
    transferring = 3,
};

const Color = extern enum(u8) {
    _0 = 0,
    _1 = 1,
    _2 = 2,
    _3 = 3,
};

const Shade = extern enum(u8) {
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
    r: u5 align(2),
    g: u5,
    b: u5,
    opaque: bool,
};

const ColorPalette = packed struct {
    _: u8,

    fn lookup(self: ColorPalette) EnumArray(Color, Shade) {
        var result: EnumArray(Color, Shade) = undefined;
        result.set(._0, @intToEnum(Shade, self._ >> (0 * 2) & 0b11));

        // I have no idea why these two values are reversed
        result.set(._1, @intToEnum(Shade, self._ >> (2 * 2) & 0b11));
        result.set(._2, @intToEnum(Shade, self._ >> (1 * 2) & 0b11));

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

const SpritePalette = packed enum(u1) {
    OBP0 = 0,
    OBP1 = 1,
};

const TileAddressing = packed enum(u1) {
    _8800 = 0,
    _8000 = 1,

    pub fn translate(self: TileAddressing, idx: u8) u9 {
        return if (idx >= 128 or self == ._8000) idx else idx + @as(u9, 256);
    }
};

const TileMapAddressing = packed enum(u1) {
    _9800 = 0,
    _9C00 = 1,
};

pub const Vram = packed struct {
    patterns: [3 * 128]RawPattern,

    tile_maps: packed struct {
        _9800: Matrix(u8, 32, 32), // $9800-9BFF
        _9C00: Matrix(u8, 32, 32), // $9C00-9FFF

        pub fn get(self: @This(), addressing: TileMapAddressing) Matrix(u8, 32, 32) {
            return switch (addressing) {
                ._9800 => self._9800,
                ._9C00 => self._9C00,
            };
        }
    },
};

pub const Video = struct {
    buffers: [2]Matrix(Pixel, SCREEN_WIDTH, SCREEN_HEIGHT),
    screen_index: u1,

    clock: extern struct {
        line: u32,
        offset: u32,
    },
    cache: struct {
        const CachedPattern = Matrix(Color, 8, 8);

        const TilesCache = struct {
            data: Matrix(Pixel, 256, 256),
            dirty: bool,

            fn run(self: *@This(), mmu: main.Mmu, patternsData: []CachedPattern, tile_map_addr: TileMapAddressing) void {
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
            pub fn toMatrixSlice(self: *@This()) MatrixSlice(u8) {
                return .{
                    .ptr = @ptrCast([*]u8, &self.data),
                    .width = CachedPattern.width,
                    .height = CachedPattern.height * self.data.len,
                };
            }

            fn run(self: *@This(), mmu: main.Mmu) void {
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
            prev_oam: [40]SpriteAttr,

            fn oamLessThan(context: void, lhs: SpriteAttr, rhs: SpriteAttr) bool {
                return lhs.x_pos < rhs.x_pos;
            }

            fn run(self: *@This(), mmu: main.Mmu, patternsData: []CachedPattern) void {
                if (!self.dirty) return;
                self.dirty = false;

                const width = 8;
                const height: usize = switch (mmu.dyn.io.video.LCDC.obj_size) {
                    .Small => 8,
                    .Large => 16,
                };

                for (self.prev_oam) |prev, i| {
                    const curr = mmu.dyn.oam[i];
                    if (@bitCast(u32, prev) == @bitCast(u32, curr)) continue;

                    var y: usize = 0;
                    while (y < height) : (y += 1) {
                        const ys = prev.y_pos + y;

                        const slice = self.data.sliceLine(prev.x_pos, ys);
                        std.mem.set(Pixel, slice[0..width], Shade.White.asPixel());
                    }
                }
                std.mem.copy(SpriteAttr, &self.prev_oam, &mmu.dyn.oam);

                var sorted = mmu.dyn.oam;
                std.sort.insertionSort(SpriteAttr, &sorted, {}, oamLessThan);
                // Lower == higher priority, so we need to iterate backwards for painters algorithm
                // TODO: ignore sprites > 10
                std.mem.reverse(SpriteAttr, &sorted);

                const obp0 = mmu.dyn.io.video.OBP0.lookup();
                const obp1 = mmu.dyn.io.video.OBP1.lookup();

                const mask: u8 = switch (mmu.dyn.io.video.LCDC.obj_size) {
                    .Small => 0xFF,
                    .Large => 0xFE,
                };
                for (sorted) |sprite_attr, i| {
                    const palette = switch (sprite_attr.flags.palette) {
                        .OBP0 => obp0,
                        .OBP1 => obp1,
                    };

                    var pattern = patternsData[sprite_attr.pattern & mask].toSlice();
                    // Large sprites are right next to each other in memory
                    // So we can simply expand this height
                    pattern.height = height;

                    var x: usize = 0;
                    while (x < pattern.width) : (x += 1) {
                        const xs = sprite_attr.x_pos +
                            if (sprite_attr.flags.x_flip) pattern.width - x - 1 else x;

                        var y: usize = 0;
                        while (y < pattern.height) : (y += 1) {
                            const ys = sprite_attr.y_pos +
                                if (sprite_attr.flags.y_flip) pattern.height - y - 1 else y;

                            const color = pattern.get(x, y);

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

    pub fn screen(self: *Video) *Matrix(Pixel, SCREEN_WIDTH, SCREEN_HEIGHT) {
        return &self.buffers[self.screen_index];
    }

    pub fn reset(self: *Video) void {
        self.buffers[0].reset(Shade.White.asPixel());
        self.screen_index = 0;
        self.clock.offset = 0;
        self.clock.line = 0;

        self.resetCache();
    }

    pub fn resetCache(self: *Video) void {
        self.cache.sprites.dirty = true;
        self.cache.sprites.data.reset(Shade.White.asPixel());
        self.cache.patterns.dirty = true;
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
            0xFF46, 0xFF48, 0xFF49 => {
                self.cache.sprites.dirty = true;
            },
            else => {},
        }
    }

    pub fn step(self: *Video, mmu: *main.Mmu, cycles: u16, catchup: bool) void {
        // FIXME: this isn't how DMA works
        if (mmu.dyn.io.video.DMA != 0) {
            const addr = @intCast(u16, mmu.dyn.io.video.DMA) << 8;
            const oam = std.mem.asBytes(&mmu.dyn.oam);
            std.mem.copy(u8, oam, std.mem.asBytes(&mmu.dyn)[addr..][0..oam.len]);

            mmu.dyn.io.video.DMA = 0;
            self.cache.sprites.dirty = true;
        }

        if (!mmu.dyn.io.video.LCDC.lcd_enable) {
            if (self.clock.line != 0 or self.clock.offset != 0) {
                mmu.dyn.io.video.STAT.mode = .hblank;
                self.reset();
            }
            return;
        }

        self.clock.offset += cycles;

        // Manually wrapping this reduces overhead by ~20%
        // compared to using division + modulus
        if (self.clock.offset >= DOTS_PER_LINE) {
            self.clock.offset -= DOTS_PER_LINE;
            self.clock.line += 1;

            if (self.clock.line >= RENDER_LINES) {
                self.clock.line -= RENDER_LINES;
            }
        }

        const line_num = self.clock.line;
        const line_offset = self.clock.offset;

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
            @as(LcdcMode, switch (line_offset) {
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
                // TODO: ready the pixel gun here
                if (mmu.dyn.io.video.STAT.irq_oam) {
                    mmu.dyn.io.IF.lcd_stat = true;
                }
            },
            .transferring => {
                if (!catchup) {
                    @call(.{ .modifier = .never_inline }, self.render, .{ mmu.*, line_num });
                }
            },
            .hblank => {
                if (mmu.dyn.io.video.STAT.irq_hblank) {
                    mmu.dyn.io.IF.lcd_stat = true;
                }
            },
            .vblank => {
                self.screen_index ^= 1;

                mmu.dyn.io.IF.vblank = true;
                if (mmu.dyn.io.video.STAT.irq_vblank) {
                    mmu.dyn.io.IF.lcd_stat = true;
                }
            },
        }
    }

    // TODO: audit this function
    fn render(self: *Video, mmu: main.Mmu, y: usize) void {
        // TODO: Cache specific lines instead of doing it all at once
        @call(.{ .modifier = .never_inline }, self.cache.patterns.run, .{mmu});
        @call(.{ .modifier = .never_inline }, self.cache.sprites.run, .{ mmu, &self.cache.patterns.data });
        @call(.{ .modifier = .never_inline }, self.cache.background.run, .{ mmu, &self.cache.patterns.data, mmu.dyn.io.video.LCDC.bg_tile_map });
        @call(.{ .modifier = .never_inline }, self.cache.window.run, .{ mmu, &self.cache.patterns.data, mmu.dyn.io.video.LCDC.window_tile_map });

        const draw_index = self.screen_index ^ 1;
        const line = self.buffers[draw_index].sliceLine(0, y);

        if (mmu.dyn.io.video.LCDC.bg_enable) {
            const xbg = mmu.dyn.io.video.SCX % self.cache.background.data.width;
            const ybg = (mmu.dyn.io.video.SCY + y) % self.cache.background.data.height;

            const bg_line = self.cache.background.data.sliceLine(0, ybg);
            const bg_start = bg_line[xbg..];
            const split_idx = std.math.min(bg_start.len, line.len);
            std.mem.copy(Pixel, line, bg_start[0..split_idx]);
            std.mem.copy(Pixel, line[split_idx..], bg_line[0 .. line.len - split_idx]);
        } else {
            std.mem.set(Pixel, line, Shade.White.asPixel());
        }

        if (mmu.dyn.io.video.LCDC.window_enable and y >= mmu.dyn.io.video.WY) {
            const win_line = self.cache.window.data.sliceLine(0, y - mmu.dyn.io.video.WY);
            if (mmu.dyn.io.video.WX < 7) {
                // TODO: add hardware bugs
                const xw = 7 - mmu.dyn.io.video.WX;
                std.mem.copy(Pixel, line, win_line[xw..][0..line.len]);
            } else {
                const xw = mmu.dyn.io.video.WX - 7;
                std.mem.copy(Pixel, line[xw..], win_line[0 .. line.len - xw]);
            }
        }

        if (mmu.dyn.io.video.LCDC.obj_enable) {
            const sprites = self.cache.sprites.data.sliceLine(8, y + 16)[0..SCREEN_WIDTH];
            const metas = self.cache.sprites.meta.sliceLine(8, y + 16);

            // TODO: use real vectors
            for (std.mem.bytesAsSlice(u64, std.mem.sliceAsBytes(sprites))) |chunk, i| {
                if (chunk == 0) continue;

                for (@bitCast([4]Pixel, chunk)) |pixel, j| {
                    const x = 4 * i + j;
                    if (pixel.opaque and (metas[x].in_front or !line[x].opaque)) {
                        line[x] = pixel;
                    }
                }
            }
        }
    }
};
