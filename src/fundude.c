#include "fundude.h"
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
  fd->mode = SYS_NORM;
}

int fd_disassemble(fundude* fd, char* out) {
  if (fd->mode == SYS_FATAL) {
    return -99999;
  }

  fd->reg.HL._ = BEYOND_CART;
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

int fd_step_frame(fundude* fd) {
  return fd_step_duration(fd, CYCLES_PER_FRAME);
}

int fd_step_duration(fundude* fd, uint32_t duration) {
  if (fd->mode == SYS_FATAL) {
    return -9999;
  }

  int64_t cycles = to_cycles(duration);
  do {
    op_result res = op_tick(fd, fdm_ptr(&fd->mem, fd->reg.PC._));
    if (res.jump <= 0 || res.length <= 0 || res.duration <= 0) {
      fd->mode = SYS_FATAL;
      return -9999;
    }

    fd->reg.PC._ = res.jump;
    cycles -= res.duration;
  } while(cycles >= 0 && fd->breakpoint != fd->reg.PC._);

  return fd->reg.PC._;
}

uint64_t to_cycles(uint32_t us) {
  return (uint64_t)us * MHz / 1000000;
}
uint32_t to_us(uint64_t clock) {
  return clock * 1000000 / MHz;
}
