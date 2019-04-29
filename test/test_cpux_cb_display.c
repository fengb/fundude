#include <stdio.h>
#include "cpux.h"
#include "mmux.h"

int main() {
  fundude fd;
  fd.mmu.cart = fd.mmu.ram;
  fd.mmu.cart_length = 0;
  char buf[100];
  uint8_t op[2] = {0xCB, 0};

  for (int h = 0; h <= 0xF; h++) {
    for (int l = 0; l <= 0xF; l++) {
      fd.cpu.HL._ = BEYOND_CART;
      op[1] = (h << 4) | l;
      cpu_result r = cpu_tick(&fd, op);
      zasm_puts(buf, sizeof(buf), r.zasm);
      printf("%-11s|", buf);
    }
    printf("\n");
    for (int l = 0; l <= 0xF; l++) {
      op[1] = (h << 4) | l;
      cpu_result r = cpu_tick(&fd, op);
      printf("%2d %3d     |", r.length, r.duration);
    }
    printf("\n\n");
  }

  return 0;
}
