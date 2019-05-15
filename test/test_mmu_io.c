#include <stddef.h>
#include "mmu.h"
#include "tap_eq.h"

int main() {
  plan(13);

  eqhex(sizeof(mmu_io), 0x4C);

  eqhex(offsetof(mmu_io, timer), 0x04);
  eqhex(offsetof(mmu_io, IF), 0x0F);

  eqhex(offsetof(mmu_io, apu), 0x10);
  eqhex(offsetof(apu_io, NR10), 0x00);
  eqhex(offsetof(apu_io, NR34), 0x0E);
  eqhex(offsetof(apu_io, NR41), 0x10);
  eqhex(offsetof(apu_io, NR52), 0x16);
  eqhex(offsetof(apu_io, wave_pattern), 0x20);

  eqhex(offsetof(mmu_io, ppu), 0x40);
  eqhex(offsetof(ppu_io, LCDC), 0x0);
  eqhex(offsetof(ppu_io, OBP1), 0x9);
  eqhex(offsetof(ppu_io, WY), 0xA);

  done_testing();
}
