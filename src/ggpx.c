#include "ggpx.h"
#include "bit.h"

typedef
  struct {
    uint8_t read : 4;
    bool dpad : 1;
    bool button : 1;
    uint8_t _padding : 2;
} HACK_GGP;

void ggp_set(fundude* fd, uint8_t val) {
  fd->mmu.io.P1._ = val;
  ggp_sync(fd);
}

void ggp_sync(fundude* fd) {
  HACK_GGP* ggp = (HACK_GGP*)&fd->mmu.io.P1._;
  // 0 == selected (...)
  if (ggp->button == 0) {
    ggp->read = ggp_buttons(fd->inputs);
    return;
  }
  if (ggp->dpad == 0) {
    ggp->read = ggp_dpad(fd->inputs);
    return;
  }
}

uint8_t ggp_dpad(uint8_t input) {
  return ~NIBBLE_LO(input) & 0xF;
}

uint8_t ggp_buttons(uint8_t input) {
  return ~NIBBLE_HI(input) & 0xF;
}
