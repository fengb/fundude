const BG_TILES = (32 * 32);

const ColorPalette = packed struct {
    _: u8,
};

const Pattern = packed struct {
    _: [8]u16,
};

const PatternMap = packed struct {
    _: [BG_TILES]u8,
};

pub const Vram = packed struct {
    patterns: packed struct {
        _8000: [128]Pattern, // $8000-87FF
        _8800: [128]Pattern, // $8800-8FFF
        _9000: [128]Pattern, // $9000-97FF
    },

    tile_maps: packed struct {
        _9800: PatternMap, // $9800-9BFF
        _9C00: PatternMap, // $9C00-9FFF
    },
};

pub const SpriteAttr = packed struct {
    y_pos: u8,
    x_pos: u8,
    pattern: u8,
    flags: u8,
};

pub const Io = packed struct {
    LCDC: u8, // $FF40
    STAT: u8, // $FF41
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
