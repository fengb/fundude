#include <stddef.h>
#include "memory.h"
#include "tap.c"

#define eqhex(a, b) ok(a == b, "0x%X == 0x%X", a, b)

int main() {
  plan(9);

  eqhex(0x0, offsetof(fd_memory, cartridge));
  eqhex(0x8000, offsetof(fd_memory, vram));
  eqhex(0xA000, offsetof(fd_memory, switchable_ram));
  eqhex(0xC000, offsetof(fd_memory, ram));
  eqhex(0xE000, offsetof(fd_memory, _ram_echo));
  eqhex(0xFE00, offsetof(fd_memory, oam));
  eqhex(0xFF00, offsetof(fd_memory, io_ports));
  eqhex(0xFF80, offsetof(fd_memory, high_ram));
  eqhex(0xFFFF, offsetof(fd_memory, interrupt_enable));

  done_testing();
}
