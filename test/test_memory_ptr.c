#include <stddef.h>
#include "memory.h"
#include "tap_eq.h"

int main() {
  plan(10);

  fd_memory mem;
  eqptr(fdm_ptr(&mem, 0x0000), mem.cart);
  eqptr(fdm_ptr(&mem, 0x8000), &mem.vram);
  eqptr(fdm_ptr(&mem, 0xA000), mem.switchable_ram);
  eqptr(fdm_ptr(&mem, 0xC000), mem.ram);
  eqptr(fdm_ptr(&mem, 0xE000), mem.ram); // echo of RAM
  eqptr(fdm_ptr(&mem, 0xFE00), mem.oam);
  eqptr(fdm_ptr(&mem, 0xFF00), mem.io_ports.RAW);
  eqptr(fdm_ptr(&mem, 0xFF50), &mem.boot_complete);
  eqptr(fdm_ptr(&mem, 0xFF80), mem.high_ram);
  eqptr(fdm_ptr(&mem, 0xFFFF), &mem.interrupt_enable);

  done_testing();
}
