#ifndef __FUNDUDE_H
#define __FUNDUDE_H

#include <stddef.h>
#include <stdint.h>
#include "cpu.h"
#include "mmu.h"

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
  uint8_t display[HEIGHT][WIDTH];

  uint8_t patterns[128][192];
  uint8_t sprites[32][160];
  uint8_t background[256][256];
  uint8_t window[256][256];

  cpu cpu;
  mmu mmu;

  bool interrupt_master;

  uint8_t inputs;

  struct {
    int cpu;
    int ppu;
    uint16_t timer;
  } clock;

  uint16_t breakpoint;
  char disassembly[24];

  sys_mode mode;
} fundude;

#endif
