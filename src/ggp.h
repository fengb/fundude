#include <stdbool.h>
#include <stdint.h>

// Gamepad

typedef union {
  uint8_t _;
  struct {
    uint8_t read : 4;
    bool dpad : 1;
    bool button : 1;
    uint8_t _padding : 2;
  };
} ggp_io;

typedef enum __attribute__((__packed__)) {
  GGP_INPUT_RIGHT = 1,
  GGP_INPUT_LEFT = 2,
  GGP_INPUT_UP = 4,
  GGP_INPUT_DOWN = 8,
  GGP_INPUT_A = 16,
  GGP_INPUT_B = 32,
  GGP_INPUT_SELECT = 64,
  GGP_INPUT_START = 128,
} ggp_input;
