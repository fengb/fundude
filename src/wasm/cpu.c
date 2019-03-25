#include "cpu.h"

fd_flags to_flags(uint8_t reg8) {
  fd_flags f = {
    .Z = (reg8 >> 7 & 1),
    .N = (reg8 >> 6 & 1),
    .H = (reg8 >> 5 & 1),
    .C = (reg8 >> 4 & 1),
  };
  return f;
}

uint8_t from_flags(fd_flags f) {
  return (
    f.Z << 7 |
    f.N << 6 |
    f.H << 5 |
    f.C << 4
  );
}
