#ifndef __PPU_H
#define __PPU_H

#include <stdbool.h>
#include <stdint.h>

#define BG_TILES (32 * 32)

typedef enum __attribute__((__packed__)) {
  SHADE_WHITE = 0,
  SHADE_LIGHT_GRAY = 1,
  SHADE_DARK_GRAY = 2,
  SHADE_BLACK = 3,
} shade;

typedef enum __attribute__((__packed__)) {
  LCDC_HBLANK = 0,
  LCDC_VBLANK = 1,
  LCDC_SEARCHING = 2,
  LCDC_TRANSFERRING = 3,
} lcdc_mode;

typedef union {
  uint8_t raw;
  struct __attribute__((__packed__)) {
    shade color0 : 2;
    shade color1 : 2;
    shade color2 : 2;
    shade color3 : 2;
  };
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
    };
  } patterns;

  ppu_pattern_map tile_map_9800;  // $9800-9BFF
  ppu_pattern_map tile_map_9C00;  // $9C00-9FFF
} ppu_vram;

typedef enum __attribute__((__packed__)) {
  PPU_SPRITE_PALETTE_OBP0,
  PPU_SPRITE_PALETTE_OBP1
} ppu_sprite_palette;

typedef struct {
  uint8_t y_pos;
  uint8_t x_pos;
  uint8_t pattern;
  struct {
    uint8_t _padding : 4;
    ppu_sprite_palette palette : 1;
    bool x_flip : 1;
    bool y_flip : 1;
    bool priority : 1;
  } flags;
} ppu_sprite_attr;

typedef struct {
  struct {
    bool bg_enable : 1;
    bool obj_enable : 1;
    uint8_t obj_size : 1;
    uint8_t bg_tile_map : 1;
    uint8_t bg_window_tile_data : 1;
    bool window_enable : 1;
    uint8_t window_tile_map : 1;
    bool lcd_enable : 1;
  } LCDC;
  struct {
    lcdc_mode mode : 2;
    bool coincidence : 1;
    bool irq_hblank : 1;
    bool irq_vblank : 1;
    bool irq_oam : 1;
    bool irq_coincidence : 1;
  } STAT;
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
