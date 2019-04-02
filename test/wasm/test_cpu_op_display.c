#include <stdio.h>
#include "cpu.h"

int main() {
  fundude fd;
  uint8_t op[] = {0x0, 0x10, 0x20};

  for (int h = 0; h <= 0xC; h++) {
    for (int l = 0; l <= 0xF; l++) {
      op[0] = (h << 4) | l;
      op_result r = fd_run(&fd, op);
      printf("%-11s|", r.op_name._);
    }
    printf("\n");
    for (int l = 0; l <= 0xF; l++) {
      op[0] = (h << 4) | l;
      op_result r = fd_run(&fd, op);
      printf("%2d %3d     |", r.length, r.duration);
    }
    printf("\n\n");
  }

  return 0;
}
