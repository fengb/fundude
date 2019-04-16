#include <stdio.h>
#include "op.h"
#include "tap.c"

int main() {
  fundude fd;
  uint8_t cart[0x4000];
  fd.mem.cart = cart;
  fd.mem.cart_length = sizeof(cart);

  char buf[100];

  uint8_t op[] = {0x0, 0x10, 0x20};

  for (int h = 0; h <= 0xF; h++) {
    for (int l = 0; l <= 0xF; l++) {
      op[0] = (h << 4) | l;
      op_result r = op_tick(&fd, op);

      ok(r.length > 0, "$%02X length > 0", op[0]);
      ok(r.duration > 0, "$%02X duration > 0", op[0]);
    }
  }

  return 0;
}
