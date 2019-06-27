#ifndef __MAIN_H
#define __MAIN_H

#include "base.h"

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
