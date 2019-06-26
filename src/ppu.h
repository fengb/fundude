#ifndef __PPU_H
#define __PPU_H

#include <stdbool.h>
#include <stdint.h>

#define BG_TILES (32 * 32)

typedef struct {
  uint8_t _;
} color_palette;

typedef struct {
  uint16_t _[8];
} ppu_pattern;

typedef struct {
  uint8_t _[BG_TILES];
} ppu_pattern_map;

typedef struct {
  union {
    ppu_pattern ALL[3 * 128];
    struct {
      ppu_pattern _8000[128];  // $8000-87FF
      ppu_pattern _8800[128];  // $8800-8FFF
      ppu_pattern _9000[128];  // $9000-97FF
    } _;
  } patterns;

  ppu_pattern_map tile_map_9800;  // $9800-9BFF
  ppu_pattern_map tile_map_9C00;  // $9C00-9FFF
} ppu_vram;

typedef struct {
  uint8_t y_pos;
  uint8_t x_pos;
  uint8_t pattern;
  uint8_t flags;
} ppu_sprite_attr;

typedef struct {
  uint8_t LCDC;        // $FF40
  uint8_t STAT;        // $FF41
  uint8_t SCY;         // $FF42
  uint8_t SCX;         // $FF43
  uint8_t LY;          // $FF44
  uint8_t LYC;         // $FF45
  uint8_t DMA;         // $FF46
  color_palette BGP;   // $FF47
  color_palette OBP0;  // $FF48
  color_palette OBP1;  // $FF49
  uint8_t WY;          // $FF4A
  uint8_t WX;          // $FF4B
} ppu_io;

#endif
