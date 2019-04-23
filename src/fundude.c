#include "fundude.h"
#include <ppu.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "op.h"

#define CYCLES_PER_FRAME 16742

fundude* fd_alloc() {
  fundude* fd = malloc(sizeof(fundude));
  return fd;
}

void fd_init(fundude* fd, size_t cart_length, uint8_t cart[]) {
  fd_reset(fd);
  fd->mem.cart_length = cart_length;
  fd->mem.cart = cart;
}

void fd_reset(fundude* fd) {
  memset(fd->display, 0, sizeof(fd->display));
  fd->reg.PC._ = 0;
  fd->mem.boot_complete = 0;
  fd->mode = SYS_NORM;
}

int fd_disassemble(fundude* fd, char* out) {
  if (fd->mode == SYS_FATAL) {
    return -99999;
  }

  fd->mem.boot_complete = 1;
  int addr = fd->reg.PC._;

  op_result res = op_tick(fd, &fd->mem.cart[addr]);

  zasm_snprintf(out, 100, res.zasm);
  fd->reg.PC._ += res.length;

  if (fd->reg.PC._ >= fd->mem.cart_length) {
    fd->mode = SYS_FATAL;
  }
  return addr;
}

int fd_step(fundude* fd) {
  if (fd->mode == SYS_FATAL) {
    return -9999;
  }

  op_result res = op_tick(fd, fdm_ptr(&fd->mem, fd->reg.PC._));
  if (res.jump <= 0 || res.length <= 0 || res.duration <= 0) {
    fd->mode = SYS_FATAL;
    return -9999;
  }

  fd->reg.PC._ = res.jump;
  return res.jump;
}

int fd_step_frames(fundude* fd, short frames) {
  int total = 0;
  while (frames --> 0) {
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
    op_result res = op_tick(fd, fdm_ptr(&fd->mem, fd->reg.PC._));
    if (res.jump <= 0 || res.length <= 0 || res.duration <= 0) {
      fd->mode = SYS_FATAL;
      return -9999;
    }

    fd->reg.PC._ = res.jump;
    cycles -= res.duration;
  } while (cycles >= 0 && fd->breakpoint != fd->reg.PC._);

  return fd->reg.PC._;
}
