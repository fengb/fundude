#include <stddef.h>
#include "memory.h"
#include "tap_eq.h"
#include <stdio.h>

int main() {
  plan(9);

  fd_memory mem;
  eqhex(fdm_ptr(&mem, 0x0000), mem.cart);
  eqhex(fdm_ptr(&mem, 0x8000), mem.vram);
  eqhex(fdm_ptr(&mem, 0xA000), mem.switchable_ram);
  eqhex(fdm_ptr(&mem, 0xC000), mem.ram);
  eqhex(fdm_ptr(&mem, 0xE000), mem.ram); // echo of RAM
  eqhex(fdm_ptr(&mem, 0xFE00), mem.oam);
  eqhex(fdm_ptr(&mem, 0xFF00), mem.io_ports.RAW);
  eqhex(fdm_ptr(&mem, 0xFF80), mem.high_ram);
  eqhex(fdm_ptr(&mem, 0xFFFF), &mem.interrupt_enable);

  done_testing();
}
