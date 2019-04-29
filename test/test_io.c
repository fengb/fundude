#include <stddef.h>
#include "io.h"
#include "tap_eq.h"

int main() {
  plan(11);

  eqhex(sizeof(io), 0x4C);

  eqhex(offsetof(io, TAC), 0x07);
  eqhex(offsetof(io, IF), 0x0F);

  eqhex(offsetof(io, NR10), 0x10);
  eqhex(offsetof(io, NR34), 0x1E);

  eqhex(offsetof(io, NR41), 0x20);
  eqhex(offsetof(io, NR52), 0x26);

  eqhex(offsetof(io, wave_pattern), 0x30);

  eqhex(offsetof(io, LCDC), 0x40);

  eqhex(offsetof(io, OBP1), 0x49);
  eqhex(offsetof(io, WY), 0x4A);

  done_testing();
}
