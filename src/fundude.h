#ifndef __FUNDUDE_H
#define __FUNDUDE_H

#include <stdint.h>
#include "memory.h"
#include "registers.h"

#define WIDTH 160
#define HEIGHT 144

#define MHz 4194304

typedef enum {
  SYS_NORM,
  SYS_HALT,
  SYS_STOP,
  SYS_FATAL, // Not a GB mode, this code is bad and we should feel bad
} sys_mode;

typedef struct {
  uint8_t display[WIDTH * HEIGHT];

  fd_registers reg;
  fd_memory mem;

  sys_mode mode;
  uint64_t cycles;
} fundude;

fundude* fd_init(uint32_t us_ref);
uint64_t to_cycles(uint32_t us);
uint32_t to_us(uint64_t clock);

#endif
