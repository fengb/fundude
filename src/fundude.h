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

  int breakpoint;
  char disassembly[24];

  sys_mode mode;
} fundude;

fundude* fd_alloc(void);
void fd_init(fundude* fd, size_t cart_length, uint8_t cart[]);
void fd_reset(fundude* fd);

int fd_step(fundude* fd);
short fd_step_frames(fundude* fd, short frames);
int fd_step_cycles(fundude* fd, int cycles);

uint8_t fd_input_press(fundude* fd, uint8_t input);
uint8_t fd_input_release(fundude* fd, uint8_t input);

#pragma mark debugging tools

char* fd_disassemble(fundude* fd);
void* fd_patterns_ptr(fundude* fd);
void* fd_background_ptr(fundude* fd);
void* fd_window_ptr(fundude* fd);
void* fd_sprites_ptr(fundude* fd);
void* fd_cpu_ptr(fundude* fd);
void* fd_mmu_ptr(fundude* fd);
void fd_set_breakpoint(fundude* fd, int breakpoint);

#endif
