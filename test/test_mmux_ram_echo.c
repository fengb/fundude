#include <stddef.h>
#include "mmux.h"
#include "tap_eq.h"

int main() {
  plan(3);

  mmu mem;
  memset(&mem, 0, sizeof(mem));

  mmu_set(&mem, 0xC000, 'A');
  eqchar('A', mmu_get(&mem, 0xE000));

  mmu_set(&mem, 0xE000, 'z');
  eqchar('z', mmu_get(&mem, 0xC000));

  mmu_set(&mem, 0xC777, '?');
  eqchar('?', mmu_get(&mem, 0xE777));

  done_testing();
}
