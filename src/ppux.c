#include "ppux.h"
#include "array.h"
#include "bit.h"

#define PIXELS_PER_TILE 8
#define BG_PIXELS 256
#define MIN(x, y) ((x) < (y) ? (x) : (y))

#define DOTS_PER_LINE 456
#define DOTS_PER_FRAME 70224

color_palette NO_PALETTE = {.color0 = 0, .color1 = 1, .color2 = 2, .color3 = 3};

enum {
  TILE_MAP_9800 = 0,
  TILE_MAP_9C00 = 1,
};

typedef enum {
  TILE_ADDRESSING_8800 = 0,
  TILE_ADDRESSING_8000 = 1,
} tile_addressing;

ppu_tile tile_data(ppu_vram* vram, tile_addressing addressing, uint8_t index) {
  if (index >= 128) {
    return vram->tile_data._8800[index - 128];
  } else if (addressing == TILE_ADDRESSING_8000) {
    return vram->tile_data._8000[index];
  } else {
    return vram->tile_data._9000[index];
  }
}

ppu_tile sprite_data(ppu_vram* vram, uint8_t index) {
  return tile_data(vram, TILE_ADDRESSING_8000, index);
}

uint8_t color_from_uint16(uint16_t val, int bit) {
  uint8_t hb = BYTE_HI(val);
  uint8_t lb = BYTE_LO(val);
  return (BIT_GET(lb, bit) << 1) | BIT_GET(hb, bit);
}

shade shade_from_color(uint8_t val, color_palette pal) {
  return (pal.raw >> (val * 2)) & 0b11;
}

void draw_tile(matrix tgt, size_t i, ppu_tile t, color_palette pal) {
  int transform = tgt.width / PIXELS_PER_TILE;
  int tx = i % transform;
  int ty = i / transform;

  for (size_t py = 0; py < PIXELS_PER_TILE; py++) {
    uint16_t line = t._[py];

    for (size_t px = 0; px < PIXELS_PER_TILE; px++) {
      uint8_t color = color_from_uint16(line, PIXELS_PER_TILE - px - 1);
      int x = tx * PIXELS_PER_TILE + px;
      int y = ty * PIXELS_PER_TILE + py;
      tgt._[y * tgt.width + x] = shade_from_color(color, pal);
    }
  }
}

// TODO: optimize by "materializing" the background instead of this shenanigans
void render_bg(fundude* fd, matrix tgt, uint8_t tile_map_flag) {
  uint8_t tile_addressing = fd->mmu.io_ports.LCDC.bg_window_tile_data;
  ppu_tile_map* tm =
      tile_map_flag == TILE_MAP_9800 ? &fd->mmu.vram.tile_map_9800 : &fd->mmu.vram.tile_map_9C00;

  for (int i = 0; i < BG_TILES; i++) {
    ppu_tile tile = tile_data(&fd->mmu.vram, tile_addressing, tm->_[i]);
    draw_tile(tgt, i, tile, fd->mmu.io_ports.BGP);
  }
}

// TODO: render over cycles instead of all at once
void ppu_render(fundude* fd) {
  for (int i = 0; i < ARRAY_LEN(fd->mmu.vram.tile_data.ALL); i++) {
    ppu_tile t = fd->mmu.vram.tile_data.ALL[i];
    draw_tile(MATRIX(fd->tile_data), i, t, NO_PALETTE);
  }
  render_bg(fd, MATRIX(fd->background), fd->mmu.io_ports.LCDC.bg_tile_map);
  render_bg(fd, MATRIX(fd->window), fd->mmu.io_ports.LCDC.window_tile_map);

  // TODO: use memcpy
  if (fd->mmu.io_ports.LCDC.bg_enable) {
    uint8_t scx = fd->mmu.io_ports.SCX;
    uint8_t scy = fd->mmu.io_ports.SCY;

    for (int y = 0; y < HEIGHT; y++) {
      for (int x = 0; x < WIDTH; x++) {
        fd->display[y][x] = fd->background[(scy + y) % BG_PIXELS][(scx + x) % BG_PIXELS];
      }
    }
  }

  if (fd->mmu.io_ports.LCDC.window_enable) {
    uint8_t wx = fd->mmu.io_ports.WX;
    uint8_t wy = fd->mmu.io_ports.WY;

    for (int y = wy; y < HEIGHT; y++) {
      for (int x = wx - 7; x < WIDTH; x++) {
        fd->display[y][x] = fd->window[wy - y][x - (wx - 7)];
      }
    }
  }
}

void ppu_step(fundude* fd, uint8_t cycles) {
  if (!fd->mmu.io_ports.LCDC.lcd_enable) {
    fd->clock.ppu = 0;
    fd->mmu.io_ports.STAT.mode = LCDC_VBLANK;
    return;
  }

  fd->clock.ppu += cycles;

  if (fd->clock.ppu > DOTS_PER_FRAME) {
    fd->clock.ppu %= DOTS_PER_FRAME;
  }

  fd->mmu.io_ports.LY = fd->clock.ppu / DOTS_PER_LINE;
  fd->mmu.io_ports.STAT.coincidence = fd->mmu.io_ports.LY == fd->mmu.io_ports.LYC;
  if ((fd->mmu.io_ports.STAT.intr_coincidence && fd->mmu.io_ports.STAT.coincidence) ||
      (fd->mmu.io_ports.STAT.intr_hblank && fd->mmu.io_ports.STAT.mode == LCDC_HBLANK) ||
      (fd->mmu.io_ports.STAT.intr_vblank && fd->mmu.io_ports.STAT.mode == LCDC_VBLANK) ||
      (fd->mmu.io_ports.STAT.intr_oam && fd->mmu.io_ports.STAT.mode == LCDC_SEARCHING)) {
    fd->mmu.io_ports.IF.lcd_stat = true;
  }

  if (fd->clock.ppu > HEIGHT * DOTS_PER_LINE) {
    // TODO: render specific pixels in mode 3 / transferring
    if (fd->mmu.io_ports.STAT.mode != LCDC_VBLANK) {
      fd->mmu.io_ports.STAT.mode = LCDC_VBLANK;
      fd->mmu.io_ports.IF.vblank = true;
      ppu_render(fd);
    }
    return;
  }

  int offset = fd->clock.ppu % DOTS_PER_LINE;
  if (offset < 80) {
    fd->mmu.io_ports.STAT.mode = LCDC_SEARCHING;
  } else if (offset < 291) {
    // TODO: depends on sprite
    fd->mmu.io_ports.STAT.mode = LCDC_TRANSFERRING;
  } else {
    fd->mmu.io_ports.STAT.mode = LCDC_HBLANK;
  }
}
