#include "ppux.h"
#include <string.h>
#include "array.h"
#include "bit.h"
#include "mmux.h"

#define PIXELS_PER_PATTERN 8
#define BG_PIXELS 256
#define MIN(x, y) ((x) < (y) ? (x) : (y))

#define DOTS_PER_LINE 456
#define DOTS_PER_FRAME 70224

static color_palette NO_PALETTE = {.color0 = 0, .color1 = 1, .color2 = 2, .color3 = 3};

enum {
  TILE_MAP_9800 = 0,
  TILE_MAP_9C00 = 1,
};

typedef enum {
  TILE_ADDRESSING_8800 = 0,
  TILE_ADDRESSING_8000 = 1,
} tile_addressing;

static ppu_pattern tile_data(ppu_vram* vram, tile_addressing addressing, uint8_t index) {
  if (index >= 128) {
    return vram->patterns._8800[index - 128];
  } else if (addressing == TILE_ADDRESSING_8000) {
    return vram->patterns._8000[index];
  } else {
    return vram->patterns._9000[index];
  }
}

static ppu_pattern sprite_data(ppu_vram* vram, uint8_t index) {
  return tile_data(vram, TILE_ADDRESSING_8000, index);
}

static uint8_t color_from_uint16(uint16_t val, int bit) {
  uint8_t hb = BYTE_HI(val);
  uint8_t lb = BYTE_LO(val);
  return (BIT_GET(lb, bit) << 1) | BIT_GET(hb, bit);
}

static shade shade_from_color(uint8_t val, color_palette pal) {
  return (pal.raw >> (val * 2)) & 0b11;
}

static void draw_pattern_xy(matrix tgt,
                            size_t x0,
                            size_t y0,
                            ppu_pattern pattern,
                            color_palette pal) {
  for (size_t py = 0; py < PIXELS_PER_PATTERN; py++) {
    uint16_t line = pattern._[py];

    for (size_t px = 0; px < PIXELS_PER_PATTERN; px++) {
      uint8_t color = color_from_uint16(line, PIXELS_PER_PATTERN - px - 1);
      int x = x0 + px;
      int y = y0 + py;
      tgt._[y * tgt.width + x] = shade_from_color(color, pal);
    }
  }
}

static void draw_pattern(matrix tgt, size_t i, ppu_pattern pattern, color_palette pal) {
  int transform = tgt.width / PIXELS_PER_PATTERN;
  int tx = i % transform;
  int ty = i / transform;

  draw_pattern_xy(tgt, tx * PIXELS_PER_PATTERN, ty * PIXELS_PER_PATTERN, pattern, pal);
}

// TODO: optimize by "materializing" the background instead of this shenanigans
static void render_bg(fundude* fd, matrix tgt, uint8_t tile_map_flag) {
  uint8_t tile_addressing = fd->mmu.io.ppu.LCDC.bg_window_tile_data;
  ppu_pattern_map* tm =
      tile_map_flag == TILE_MAP_9800 ? &fd->mmu.vram.tile_map_9800 : &fd->mmu.vram.tile_map_9C00;

  for (int i = 0; i < BG_TILES; i++) {
    ppu_pattern tile = tile_data(&fd->mmu.vram, tile_addressing, tm->_[i]);
    draw_pattern(tgt, i, tile, fd->mmu.io.ppu.BGP);
  }
}

// TODO: render over cycles instead of all at once
static void ppu_render(fundude* fd) {
  for (int i = 0; i < ARRAY_LEN(fd->mmu.vram.patterns.ALL); i++) {
    ppu_pattern p = fd->mmu.vram.patterns.ALL[i];
    draw_pattern(MATRIX(fd->patterns), i, p, NO_PALETTE);
  }
  render_bg(fd, MATRIX(fd->background), fd->mmu.io.ppu.LCDC.bg_tile_map);
  render_bg(fd, MATRIX(fd->window), fd->mmu.io.ppu.LCDC.window_tile_map);
  for (int i = 0; i < ARRAY_LEN(fd->mmu.oam); i++) {
    ppu_sprite_attr s = fd->mmu.oam[i];
    if (!s.x_pos && !s.y_pos && !s.pattern) {
      continue;
    }
    ppu_pattern pattern = sprite_data(&fd->mmu.vram, s.pattern);
    color_palette palette = s.flags.palette == PPU_SPRITE_PALETTE_OBP0  //
                                ? fd->mmu.io.ppu.OBP0
                                : fd->mmu.io.ppu.OBP1;
    draw_pattern(MATRIX(fd->sprites), i, pattern, palette);
  }

  // TODO: use memcpy
  if (fd->mmu.io.ppu.LCDC.bg_enable) {
    uint8_t scx = fd->mmu.io.ppu.SCX;
    uint8_t scy = fd->mmu.io.ppu.SCY;

    for (int y = 0; y < HEIGHT; y++) {
      for (int x = 0; x < WIDTH; x++) {
        fd->display[y][x] = fd->background[(scy + y) % BG_PIXELS][(scx + x) % BG_PIXELS];
      }
    }
  }

  if (fd->mmu.io.ppu.LCDC.window_enable) {
    uint8_t wx = fd->mmu.io.ppu.WX;
    uint8_t wy = fd->mmu.io.ppu.WY;

    for (int y = wy; y < HEIGHT; y++) {
      for (int x = wx - 7; x < WIDTH; x++) {
        fd->display[y][x] = fd->window[wy - y][x - (wx - 7)];
      }
    }
  }

  for (int i = 0; i < ARRAY_LEN(fd->mmu.oam); i++) {
    ppu_sprite_attr s = fd->mmu.oam[i];
    if (!s.x_pos && !s.y_pos) {
      continue;
    }
    ppu_pattern pattern = sprite_data(&fd->mmu.vram, s.pattern);
    color_palette palette = s.flags.palette == PPU_SPRITE_PALETTE_OBP0  //
                                ? fd->mmu.io.ppu.OBP0
                                : fd->mmu.io.ppu.OBP1;
    draw_pattern_xy(MATRIX(fd->display), s.x_pos - 8, s.y_pos - 16, pattern, palette);
  }
}

void ppu_reset(fundude* fd) {
  fd->mmu.io.ppu.STAT.mode = LCDC_VBLANK;
  fd->mmu.io.ppu.DMA = 0;
  fd->mmu.io.ppu.LCDC.lcd_enable = false;
}

void ppu_step(fundude* fd, uint8_t cycles) {
  // FIXME: this isn't how DMA works
  if (fd->mmu.io.ppu.DMA) {
    uint16_t addr = fd->mmu.io.ppu.DMA << 8;
    memcpy(&fd->mmu.oam, mmu_ptr(&fd->mmu, addr), 160);
    fd->mmu.io.ppu.DMA = 0;
  }

  if (!fd->mmu.io.ppu.LCDC.lcd_enable) {
    fd->clock.ppu = 0;
    fd->mmu.io.ppu.STAT.mode = LCDC_VBLANK;
    return;
  }

  fd->clock.ppu += cycles;

  if (fd->clock.ppu > DOTS_PER_FRAME) {
    fd->clock.ppu %= DOTS_PER_FRAME;
  }

  fd->mmu.io.ppu.LY = fd->clock.ppu / DOTS_PER_LINE;
  fd->mmu.io.ppu.STAT.coincidence = fd->mmu.io.ppu.LY == fd->mmu.io.ppu.LYC;
  if ((fd->mmu.io.ppu.STAT.irq_coincidence && fd->mmu.io.ppu.STAT.coincidence) ||
      (fd->mmu.io.ppu.STAT.irq_hblank && fd->mmu.io.ppu.STAT.mode == LCDC_HBLANK) ||
      (fd->mmu.io.ppu.STAT.irq_vblank && fd->mmu.io.ppu.STAT.mode == LCDC_VBLANK) ||
      (fd->mmu.io.ppu.STAT.irq_oam && fd->mmu.io.ppu.STAT.mode == LCDC_SEARCHING)) {
    fd->mmu.io.IF.lcd_stat = true;
  }

  if (fd->clock.ppu > HEIGHT * DOTS_PER_LINE) {
    // TODO: render specific pixels in mode 3 / transferring
    if (fd->mmu.io.ppu.STAT.mode != LCDC_VBLANK) {
      fd->mmu.io.ppu.STAT.mode = LCDC_VBLANK;
      fd->mmu.io.IF.vblank = true;
      ppu_render(fd);
    }
    return;
  }

  int offset = fd->clock.ppu % DOTS_PER_LINE;
  if (offset < 80) {
    fd->mmu.io.ppu.STAT.mode = LCDC_SEARCHING;
  } else if (offset < 291) {
    // TODO: depends on sprite
    fd->mmu.io.ppu.STAT.mode = LCDC_TRANSFERRING;
  } else {
    fd->mmu.io.ppu.STAT.mode = LCDC_HBLANK;
  }
}
