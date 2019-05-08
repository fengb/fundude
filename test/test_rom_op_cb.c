#include <stdio.h>
#include "fundude.h"
#include "mmux.h"
#include "tap_eq.h"

int main() {
  fundude fd;
  uint8_t cart[0x8000];

  FILE* rom = fopen("vendor/fundude-test/op_cb.gb", "rb");
  fseek(rom, 0L, SEEK_END);
  size_t rom_length = ftell(rom);
  rewind(rom);
  fread(&cart, sizeof(cart[0]), rom_length, rom);
  fclose(rom);

  fd_init(&fd, rom_length, cart);
  while (fd.cpu.PC._ < 0x7FFD) {
    fd_step_frames(&fd, 60);
  }

  uint8_t* cart_data = &cart[0x4000];
  uint8_t* results = mmu_ptr(&fd.mmu, fd.cpu.SP._);
  size_t length = 0xE000 - fd.cpu.SP._;

  for (size_t i = 0; i < length; i++) {
    if (results[i] != cart_data[i]) {
      ok(results[i] == cart_data[i], "0x%04X: 0x%X == 0x%X", fd.cpu.SP._ + i, results[i],
         cart_data[i]);
    }
  }

  done_testing();
}
