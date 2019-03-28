#include <stddef.h>
#include "memory.h"
#include "tap_eq.h"

int main() {
  plan(3);

  fd_memory mem;
  memset(&mem, 0, sizeof(mem));

  fdm_set(&mem, 0xC000, 'A');
  eqchar('A', fdm_get(&mem, 0xE000));

  fdm_set(&mem, 0xE000, 'z');
  eqchar('z', fdm_get(&mem, 0xC000));

  fdm_set(&mem, 0xC777, '?');
  eqchar('?', fdm_get(&mem, 0xE777));

  done_testing();
}
