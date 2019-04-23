#include "ppu.h"

#define PIXELS_PER_TILE 8
#define BACKGROUND_TILES 32
#define MIN(x, y) ((x) < (y) ? (x) : (y))

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

size_t draw_line(uint8_t tgt[], size_t max, uint16_t line, color_palette pal) {
  size_t len = MIN(max, PIXELS_PER_TILE);
  for (int i = 0; i < len; i++) {
    uint8_t color = color_from_uint16(line, i);
    tgt[i] = shade_from_color(color, pal);
  }
  return len;
}

// TODO: optimize by "materializing" the background instead of this shenanigans
void render_bg(fundude* fd, uint8_t background[256][256], uint8_t tile_map_flag) {
  uint8_t tile_addressing = fd->mem.io_ports.LCDC.bg_window_tile_data;
  tile_map* tm =
      tile_map_flag == TILE_MAP_9800 ? &fd->mem.vram.tile_map_9800 : &fd->mem.vram.tile_map_9C00;

  for (int r = 0; r < BACKGROUND_TILES; r++) {
    for (int c = 0; c < BACKGROUND_TILES; c++) {
      int tile_index = tm->_[r][c];
      tile t = tile_data(&fd->mem.vram, tile_addressing, tile_index);

      for (int y = 0; y < PIXELS_PER_TILE; y++) {
        draw_line(background[r * PIXELS_PER_TILE + y], PIXELS_PER_TILE, t._[y],
                  fd->mem.io_ports.BGP);
      }
    }
  }
}

// TODO: render over cycles instead of all at once
void ppu_render(fundude* fd) {
  render_bg(fd, fd->background, fd->mem.io_ports.LCDC.bg_tile_map);
  render_bg(fd, fd->window, fd->mem.io_ports.LCDC.window_tile_map);

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
