#include <stddef.h>
#include "memory.h"
#include "tap_eq.h"

int main() {
  plan(11);

  eqhex(sizeof(fd_io), 0x4C);

  eqhex(offsetof(fd_io, TAC), 0x07);
  eqhex(offsetof(fd_io, IF), 0x0F);

  eqhex(offsetof(fd_io, NR10), 0x10);
  eqhex(offsetof(fd_io, NR34), 0x1E);

  eqhex(offsetof(fd_io, NR41), 0x20);
  eqhex(offsetof(fd_io, NR52), 0x26);

  eqhex(offsetof(fd_io, wave_pattern), 0x30);

  eqhex(offsetof(fd_io, LCDC), 0x40);

  eqhex(offsetof(fd_io, OBP1), 0x49);
  eqhex(offsetof(fd_io, WY), 0x4A);

  done_testing();
}
