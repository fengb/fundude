#ifndef __FUNDUDE_H
#define __FUNDUDE_H

#include <stdint.h>
#include "memory.h"
#include "registers.h"

#define WIDTH 160
#define HEIGHT 144

typedef enum {
  SYS_NORM,
  SYS_HALT,
  SYS_STOP,
} sys_mode;

typedef struct {
  uint8_t display[WIDTH * HEIGHT];

  fd_registers reg;
  fd_memory mem;

  sys_mode mode;
} fundude;

fundude* fd_init(void);

#endif
