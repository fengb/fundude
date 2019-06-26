#include <stdbool.h>
#include <stdint.h>

// Gamepad

typedef struct {
  uint8_t _;
} ggp_io;

enum {
  GGP_INPUT_RIGHT = 1,
  GGP_INPUT_LEFT = 2,
  GGP_INPUT_UP = 4,
  GGP_INPUT_DOWN = 8,
  GGP_INPUT_A = 16,
  GGP_INPUT_B = 32,
  GGP_INPUT_SELECT = 64,
  GGP_INPUT_START = 128,
};
