#include <stdio.h>
#include "cpux.h"

int main() {
  fundude fd;
  uint8_t cart[0x4000];
  fd.mmu.cart = cart;
  fd.mmu.cart_length = sizeof(cart);

  char buf[100];

  uint8_t op[] = {0x0, 0x10, 0x20};

  for (int h = 0; h <= 0xF; h++) {
    for (int l = 0; l <= 0xF; l++) {
      op[0] = (h << 4) | l;
      cpu_result r = cpu_tick(&fd, op);
      zasm_puts(buf, sizeof(buf), r.zasm);
      printf("%-13s|", buf);
    }
    printf("\n");
    for (int l = 0; l <= 0xF; l++) {
      op[0] = (h << 4) | l;
      cpu_result r = cpu_tick(&fd, op);

      printf("%2d %3d       |", r.length, r.duration);
    }
    printf("\n\n");
  }

  return 0;
}
