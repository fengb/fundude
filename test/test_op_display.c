#include <stdio.h>
#include "op.h"

int main() {
  fundude fd;
  fd.mem.cart = fd.mem.ram;
  fd.mem.cart_length = 0;

  uint8_t op[] = {0x0, 0x10, 0x20};

  for (int h = 0; h <= 0xD; h++) {
    for (int l = 0; l <= 0xF; l++) {
      op[0] = (h << 4) | l;
      op_result r = op_tick(&fd, op);
      printf("%-11s|", r.op_name._);
    }
    printf("\n");
    for (int l = 0; l <= 0xF; l++) {
      op[0] = (h << 4) | l;
      op_result r = op_tick(&fd, op);
      printf("%2d %3d     |", r.length, r.duration);
    }
    printf("\n\n");
  }

  return 0;
}
