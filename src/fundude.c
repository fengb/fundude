#include "fundude.h"
#include <stdlib.h>
#include <string.h>

fundude* fd_init(uint32_t us_ref) {
  fundude* fd = malloc(sizeof(fundude));
  memset(fd->display, 0, sizeof(fd->display));
  fd->cycles = to_cycles(us_ref);
  return fd;
}

uint64_t to_cycles(uint32_t us) {
  return (uint64_t)us * MHz / 1000000;
}
uint32_t to_us(uint64_t clock) {
  return clock * 1000000 / MHz;
}
