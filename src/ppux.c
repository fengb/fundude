#include "ppux.h"

#define PIXELS_PER_TILE 8
#define BACKGROUND_TILES 32
#define MIN(x, y) ((x) < (y) ? (x) : (y))
#define ARRAYLEN(x) (sizeof(x) / sizeof(x[0]))

color_palette NO_PALETTE = {.color0 = 0, .color1 = 1, .color2 = 2, .color3 = 3};

enum {
  TILE_MAP_9800 = 0,
  TILE_MAP_9C00 = 1,
};

typedef enum {
  TILE_ADDRESSING_8000 = 0,
  TILE_ADDRESSING_8800 = 1,
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
  uint8_t hb = val >> 8;
  uint8_t lb = val & 0xFF;
  return (lb >> bit & 1) << 1 | (hb >> bit & 1);
}

shade shade_from_color(uint8_t val, color_palette pal) {
  switch (val) {
    case 0: return pal.color0;
    case 1: return pal.color1;
    case 2: return pal.color2;
    case 3: return pal.color3;
    default: return 0xFF;
  }
}

void draw_tile(uint8_t tgt[][256], size_t r, size_t c, ppu_tile t, color_palette pal) {
  for (size_t y = 0; y < PIXELS_PER_TILE; y++) {
    uint16_t line = t._[y];

    for (size_t x = 0; x < PIXELS_PER_TILE; x++) {
      uint8_t color = color_from_uint16(line, PIXELS_PER_TILE - x - 1);
      tgt[r * PIXELS_PER_TILE + y][c * PIXELS_PER_TILE + x] = shade_from_color(color, pal);
    }
  }
}

// TODO: optimize by "materializing" the background instead of this shenanigans
void render_bg(fundude* fd, uint8_t background[256][256], uint8_t tile_map_flag) {
  uint8_t tile_addressing = fd->mmu.io_ports.LCDC.bg_window_tile_data;
  ppu_tile_map* tm =
      tile_map_flag == TILE_MAP_9800 ? &fd->mmu.vram.tile_map_9800 : &fd->mmu.vram.tile_map_9C00;

  for (int r = 0; r < BACKGROUND_TILES; r++) {
    for (int c = 0; c < BACKGROUND_TILES; c++) {
      int tile_index = tm->_[r][c];
      ppu_tile t = tile_data(&fd->mmu.vram, tile_addressing, tile_index);

      draw_tile(background, r, c, t, fd->mmu.io_ports.BGP);
    }
  }
}

// TODO: render over cycles instead of all at once
void ppu_render(fundude* fd) {
  for (int i = 0; i < ARRAYLEN(fd->mmu.vram.tile_data.ALL); i++) {
    ppu_tile t = fd->mmu.vram.tile_data.ALL[i];
    int c = i % BACKGROUND_TILES;
    int r = i / BACKGROUND_TILES;

    draw_tile(fd->tile_data, r, c, t, NO_PALETTE);
  }
  render_bg(fd, fd->background, fd->mmu.io_ports.LCDC.bg_tile_map);
  render_bg(fd, fd->window, fd->mmu.io_ports.LCDC.window_tile_map);

  uint8_t scx = fd->mmu.io_ports.SCX;
  uint8_t scy = fd->mmu.io_ports.SCY;

  // TODO: use memcpy
  for (int x = 0; x < WIDTH; x++) {
    for (int y = 0; y < HEIGHT; y++) {
      int display_offset = y * HEIGHT + x;
      fd->display[display_offset] = fd->background[(scy + y) % HEIGHT][(scx + x) % WIDTH];
    }
  }
}
