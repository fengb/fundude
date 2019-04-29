#include "fundude.h"
#include <stdlib.h>
#include <string.h>
#include "cpux.h"
#include "mmux.h"
#include "ppux.h"

#define CYCLES_PER_FRAME 16742

fundude* fd_alloc() {
  fundude* fd = malloc(sizeof(fundude));
  return fd;
}

void fd_init(fundude* fd, size_t cart_length, uint8_t cart[]) {
  fd_reset(fd);
  fd->mmu.cart_length = cart_length;
  fd->mmu.cart = cart;
}

void fd_reset(fundude* fd) {
  memset(fd->display, 0, sizeof(fd->display));
  fd->cpu.PC._ = 0;
  fd->mmu.boot_complete = 0;
  fd->mode = SYS_NORM;
}

int fd_step(fundude* fd) {
  if (fd->mode == SYS_FATAL) {
    return -9999;
  }

  cpu_result res = cpu_tick(fd, mmu_ptr(&fd->mmu, fd->cpu.PC._));
  if (res.jump <= 0 || res.length <= 0 || res.duration <= 0) {
    fd->mode = SYS_FATAL;
    return -9999;
  }

  fd->cpu.PC._ = res.jump;
  return res.jump;
}

int fd_step_frames(fundude* fd, short frames) {
  int total = 0;
  while (frames-- > 0) {
    total += fd_step_cycles(fd, CYCLES_PER_FRAME);
    ppu_render(fd);
  }
  return total;
}

int fd_step_cycles(fundude* fd, int cycles) {
  if (fd->mode == SYS_FATAL) {
    return -9999;
  }

  do {
    cpu_result res = cpu_tick(fd, mmu_ptr(&fd->mmu, fd->cpu.PC._));
    if (res.jump <= 0 || res.length <= 0 || res.duration <= 0) {
      fd->mode = SYS_FATAL;
      return -9999;
    }

    fd->cpu.PC._ = res.jump;
    cycles -= res.duration;
  } while (cycles >= 0 && fd->breakpoint != fd->cpu.PC._);

  return fd->cpu.PC._;
}

char* fd_disassemble(fundude* fd) {
  if (fd->mode == SYS_FATAL) {
    return NULL;
  }

  fd->mmu.boot_complete = 1;
  int addr = fd->cpu.PC._;

  cpu_result res = cpu_tick(fd, &fd->mmu.cart[addr]);

  zasm_puts(fd->disassembly, sizeof(fd->disassembly), res.zasm);
  fd->cpu.PC._ += res.length;

  if (fd->cpu.PC._ >= fd->mmu.cart_length) {
    fd->mode = SYS_FATAL;
  }
  return fd->disassembly;
}

void* fd_background_ptr(fundude* fd) {
  return &fd->background;
}

void* fd_window_ptr(fundude* fd) {
  return &fd->window;
}

void* fd_tile_data_ptr(fundude* fd) {
  return &fd->tile_data;
}

void* fd_cpu_ptr(fundude* fd) {
  return &fd->cpu;
}

void* fd_mmu_ptr(fundude* fd) {
  return &fd->mmu;
}

void fd_set_breakpoint(fundude* fd, int breakpoint) {
  fd->breakpoint = breakpoint;
}
