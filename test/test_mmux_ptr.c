#include <stdbool.h>
#include <stddef.h>
#include "mmux.h"
#include "tap_eq.h"

int main() {
  plan(11);

  mmu mmu;
  mmu.boot_complete = false;
  eqptr(mmu_ptr(&mmu, 0x0000), BOOTLOADER);

  mmu.boot_complete = true;
  eqptr(mmu_ptr(&mmu, 0x0000), mmu.cart);
  eqptr(mmu_ptr(&mmu, 0x8000), &mmu.vram);
  eqptr(mmu_ptr(&mmu, 0xA000), mmu.switchable_ram);
  eqptr(mmu_ptr(&mmu, 0xC000), mmu.ram);
  eqptr(mmu_ptr(&mmu, 0xE000), mmu.ram);  // echo of RAM
  eqptr(mmu_ptr(&mmu, 0xFE00), mmu.oam);
  eqptr(mmu_ptr(&mmu, 0xFF00), mmu.io_ports.RAW);
  eqptr(mmu_ptr(&mmu, 0xFF50), &mmu.boot_complete);
  eqptr(mmu_ptr(&mmu, 0xFF80), mmu.high_ram);
  eqptr(mmu_ptr(&mmu, 0xFFFF), &mmu.interrupt_enable);

  done_testing();
}
