#include <stdbool.h>
#include <stdint.h>

typedef struct {
  uint16_t _[8];
} tile;

typedef struct {
  tile tile_data_8000[128];  // $8000-87FF
  tile tile_data_8800[128];  // $8800-8FFF
  tile tile_data_9000[128];  // $9000-97FF

  uint8_t tile_map_9800[0x0400];  // $9800-9BFF
  uint8_t tile_map_9C00[0x0400];  // $9C00-9FFF
} fd_vram;

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
} sprite_attr;
