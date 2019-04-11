#include <stdio.h>
#include "op.h"

int main() {
  fundude fd;
  fd.mem.cart = fd.mem.ram;
  fd.mem.cart_length = 0;
  char buf[100];
  uint8_t op[2] = {0xCB, 0};

  for (int h = 0; h <= 0xF; h++) {
    for (int l = 0; l <= 0xF; l++) {
      fd.reg.HL._ = BEYOND_CART;
      op[1] = (h << 4) | l;
      op_result r = op_tick(&fd, op);
      zasm_snprintf(buf, sizeof(buf), r.zasm);
      printf("%-11s|", buf);
    }
    printf("\n");
    for (int l = 0; l <= 0xF; l++) {
      op[1] = (h << 4) | l;
      op_result r = op_tick(&fd, op);
      printf("%2d %3d     |", r.length, r.duration);
    }
    printf("\n\n");
  }

  return 0;
}
