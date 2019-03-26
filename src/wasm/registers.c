#include "registers.h"
#include <assert.h>

fd_flags fd_get_flags(fd_registers* reg) {
  uint8_t val = reg->F._;
  fd_flags f = {
      .Z = (val >> 7 & 1),
      .N = (val >> 6 & 1),
      .H = (val >> 5 & 1),
      .C = (val >> 4 & 1),
  };
  return f;
}

uint8_t fd_set_flags(fd_registers* reg, fd_flags f) {
  uint8_t val = (f.Z << 7 | f.N << 6 | f.H << 5 | f.C << 4);
  reg->F._ = val;
  return val;
}
