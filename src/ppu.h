#include <stdbool.h>
#include <stdint.h>

#define BG_TILES (32 * 32)

typedef struct {
  uint16_t _[8];
} ppu_tile;

typedef struct {
  uint8_t _[BG_TILES];
} ppu_tile_map;

typedef struct {
  union {
    ppu_tile ALL[3 * 128];
    struct {
      ppu_tile _8000[128];  // $8000-87FF
      ppu_tile _8800[128];  // $8800-8FFF
      ppu_tile _9000[128];  // $9000-97FF
    };
  } tile_data;

  ppu_tile_map tile_map_9800;  // $9800-9BFF
  ppu_tile_map tile_map_9C00;  // $9C00-9FFF
} ppu_vram;

typedef struct {
  uint8_t y_pos;
  uint8_t x_pos;
  uint8_t pattern;
  struct {
    uint8_t _padding : 4;
    bool palette : 1;
    bool x_flip : 1;
    bool y_flip : 1;
    bool priority : 1;
  } flags;
} ppu_sprite_attr;
