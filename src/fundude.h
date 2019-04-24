#ifndef __FUNDUDE_H
#define __FUNDUDE_H

#include <stddef.h>
#include <stdint.h>
#include "cart.h"
#include "memory.h"
#include "registers.h"

#define WIDTH 160
#define HEIGHT 144

#define MHz 4194304

typedef enum {
  SYS_NORM,
  SYS_HALT,
  SYS_STOP,
  SYS_FATAL,  // Not a GB mode, this code is bad and we should feel bad
} sys_mode;

typedef struct {
  uint8_t display[WIDTH * HEIGHT];
  uint8_t background[256][256];
  uint8_t window[256][256];
  uint8_t tile_data[96][256];

  fd_registers reg;
  fd_memory mem;

  int breakpoint;

  sys_mode mode;
} fundude;

fundude* fd_alloc(void);
void fd_init(fundude* fd, size_t cart_length, uint8_t cart[]);
void fd_reset(fundude* fd);

int fd_disassemble(fundude* fd, char* out);

int fd_step(fundude* fd);
int fd_step_frames(fundude* fd, short frames);
int fd_step_cycles(fundude* fd, int cycles);

uint64_t to_cycles(uint32_t us);
uint32_t to_us(uint64_t clock);

#endif
