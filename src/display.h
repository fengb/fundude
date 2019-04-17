#include <stdbool.h>
#include <stdint.h>

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
