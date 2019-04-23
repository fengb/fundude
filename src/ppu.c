#include "ppu.h"

#define PIXELS_PER_TILE 8
#define BACKGROUND_TILES 32

enum {
  TILE_MAP_9800 = 0,
  TILE_MAP_9C00 = 1,
};

typedef enum {
  TILE_ADDRESSING_8000 = 0,
  TILE_ADDRESSING_8800 = 1,
} tile_addressing;

tile tile_data(fd_vram* vram, tile_addressing addressing, uint8_t index) {
  if (index >= 128) {
    return vram->tile_data_8800[index - 128];
  } else if (addressing == TILE_ADDRESSING_8000) {
    return vram->tile_data_8000[index];
  } else {
    return vram->tile_data_9000[index];
  }
}

tile sprite_data(fd_vram* vram, uint8_t index) {
  return tile_data(vram, TILE_ADDRESSING_8000, index);
}

uint8_t color_from_uint16(uint16_t val, int bit) {
  uint8_t hb = val >> 8;
  uint8_t lb = val & 0xFF;
  return (lb >> bit & 1) << 1 & (hb >> bit & 1);
}

shade shade_from_color(uint8_t val, color_palette pal) {
  switch (val) {
    case 0: return pal.color0;
    case 1: return pal.color1;
    case 2: return pal.color2;
    case 3: return pal.color3;
  }
}

// TODO: optimize by "materializing" the background instead of this shenanigans
void render_bg(fundude* fd) {
  uint8_t tile_addressing = fd->mem.io_ports.LCDC.bg_window_tile_data;
  for (int r = 0; r < BACKGROUND_TILES; r++) {
    for (int c = 0; c < BACKGROUND_TILES; c++) {
      int tile_index = fd->mem.io_ports.LCDC.bg_tile_map == TILE_MAP_9800
                           ? fd->mem.vram.tile_map_9800[r][c]
                           : fd->mem.vram.tile_map_9C00[r][c];
      tile t = tile_data(&fd->mem.vram, tile_addressing, tile_index);

      for (int y = 0; y < PIXELS_PER_TILE; y++) {
        uint16_t line = t._[y];
        for (int x = 0; x < PIXELS_PER_TILE; x++) {
          uint8_t color = color_from_uint16(line, x);
          uint8_t shade = shade_from_color(color, fd->mem.io_ports.BGP);
          fd->background[r * PIXELS_PER_TILE + y][c * PIXELS_PER_TILE + x] = shade;
        }
      }
    }
  }
}

// TODO: render over cycles instead of all at once
void ppu_render(fundude* fd) {
  render_bg(fd);

  uint8_t scx = fd->mem.io_ports.SCX;
  uint8_t scy = fd->mem.io_ports.SCY;

  // TODO: use memcpy
  for (int x = 0; x < WIDTH; x++) {
    for (int y = 0; y < HEIGHT; y++) {
      int display_offset = y * HEIGHT + x;
      fd->display[display_offset] = fd->background[(scy + y) % HEIGHT][(scx + x) % WIDTH];
    }
  }
}
