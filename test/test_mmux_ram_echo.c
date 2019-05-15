#include <stddef.h>
#include "mmux.h"
#include "tap_eq.h"

int main() {
  plan(3);

  fundude fd;
  memset(&fd.mmu, 0, sizeof(fd.mmu));

  mmu_set(&fd, 0xC000, 'A');
  eqchar('A', mmu_get(&fd.mmu, 0xE000));

  mmu_set(&fd, 0xE000, 'z');
  eqchar('z', mmu_get(&fd.mmu, 0xC000));

  mmu_set(&fd, 0xC777, '?');
  eqchar('?', mmu_get(&fd.mmu, 0xE777));

  done_testing();
}
