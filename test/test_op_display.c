#include <stdio.h>
#include "op.h"

int main() {
  fundude fd;
  fd.mem.cart = fd.mem.ram;
  fd.mem.cart_length = 0;

  uint8_t op[] = {0x0, 0x10, 0x20};

  for (int h = 0; h <= 0xF; h++) {
    for (int l = 0; l <= 0xF; l++) {
      op[0] = (h << 4) | l;
      op_result r = op_tick(&fd, op);
      if (r.length) {
        printf("%-13s|", r.op_name._);
      } else {
        printf("%-13s|", "");
      }
    }
    printf("\n");
    for (int l = 0; l <= 0xF; l++) {
      op[0] = (h << 4) | l;
      op_result r = op_tick(&fd, op);

      if (r.length) {
        printf("%2d %3d       |", r.length, r.duration);
      } else {
        printf("%-13s|", "");
      }
    }
    printf("\n\n");
  }

  return 0;
}
