#include "ggpx.h"
#include "bit.h"

void ggp_set(fundude* fd, uint8_t val) {
  fd->mmu.io.P1._ = val;
  ggp_sync(fd);
}

void ggp_sync(fundude* fd) {
  // 0 == selected (...)
  if (fd->mmu.io.P1.button == 0) {
    fd->mmu.io.P1.read = ggp_buttons(fd->inputs);
    return;
  }
  if (fd->mmu.io.P1.dpad == 0) {
    fd->mmu.io.P1.read = ggp_dpad(fd->inputs);
    return;
  }
}

uint8_t ggp_dpad(ggp_input input) {
  return ~NIBBLE_LO(input) & 0xF;
}

uint8_t ggp_buttons(ggp_input input) {
  return ~NIBBLE_HI(input) & 0xF;
}
