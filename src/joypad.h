#include <stdint.h>

typedef union {
  uint8_t _;
  struct {
    bool P10 : 1;
    bool P11 : 1;
    bool P12 : 1;
    bool P13 : 1;
    bool P14 : 1;
    bool P15 : 1;
    uint8_t _padding : 2;
  };
} joypad_io;
