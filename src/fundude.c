#include "fundude.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "op.h"

fundude* fd_init(uint32_t us_ref, size_t cart_length, uint8_t cart[]) {
  fundude* fd = malloc(sizeof(fundude));
  fd_reset(fd, us_ref, cart_length, cart);
  return fd;
}

void fd_reset(fundude* fd, uint32_t us_ref, size_t cart_length, uint8_t cart[]) {
  memset(fd->display, 0, sizeof(fd->display));
  if (cart_length && cart != NULL) {
    fd->mem.cart_length = cart_length;
    fd->mem.cart = cart;
  }
  fd->cycles = to_cycles(us_ref);
}

int fd_disassemble(fundude* fd, char* out) {
  if (fd->mode == SYS_FATAL) {
    return 1;
  }

  op_result res = op_tick(fd, &fd->mem.cart[fd->reg.PC._]);

  sprintf(out, "0x%04X %s", fd->reg.PC._, res.op_name._);
  fd->reg.PC._ += res.length;

  if (res.jump <= 0 || res.length <= 0 || res.duration <= 0 ||
      fd->reg.PC._ >= fd->mem.cart_length) {
    fd->mode = SYS_FATAL;
  }
  return fd->mode == SYS_FATAL;
}

uint64_t to_cycles(uint32_t us) {
  return (uint64_t)us * MHz / 1000000;
}
uint32_t to_us(uint64_t clock) {
  return clock * 1000000 / MHz;
}
