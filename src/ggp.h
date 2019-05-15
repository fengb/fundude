#include <stdbool.h>
#include <stdint.h>

// Gamepad

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
} ggp_io;

typedef enum __attribute__((__packed__)) {
  GGP_BUTTON_RIGHT = 1,
  GGP_BUTTON_LEFT = 2,
  GGP_BUTTON_UP = 4,
  GGP_BUTTON_DOWN = 8,
  GGP_BUTTON_A = 16,
  GGP_BUTTON_B = 32,
  GGP_BUTTON_SELECT = 64,
  GGP_BUTTON_START = 128,
} ggp_button;
