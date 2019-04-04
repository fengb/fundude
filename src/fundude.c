#include "fundude.h"
#include <stdlib.h>
#include <string.h>

fundude* fd_init(uint32_t us_ref, uint8_t cart[]) {
  fundude* fd = malloc(sizeof(fundude));
  fd_reset(fd, us_ref, cart);
  return fd;
}

void fd_reset(fundude* fd, uint32_t us_ref, uint8_t cart[]) {
  memset(fd->display, 0, sizeof(fd->display));
  if (cart != NULL) {
    fd->cart = cart;
  }
  fd->cycles = to_cycles(us_ref);
}

uint64_t to_cycles(uint32_t us) {
  return (uint64_t)us * MHz / 1000000;
}
uint32_t to_us(uint64_t clock) {
  return clock * 1000000 / MHz;
}
