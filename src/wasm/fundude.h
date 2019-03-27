#include <stdint.h>
#include "memory.h"
#include "registers.h"

#define WIDTH 160
#define HEIGHT 144

typedef struct {
  uint8_t display[WIDTH * HEIGHT];

  fd_registers reg;
  fd_memory mem;
} fundude;

fundude* fd_init(void);
