#include <stdio.h>
#include "op_cb.h"

int main() {
  fundude fd;

  for (int h = 0; h <= 0xC; h++) {
    for (int l = 0; l <= 0xF; l++) {
      uint8_t op = (h << 4) | l;
      op_result r = op_cb(&fd, op);
      printf("%-11s|", r.op_name._);
    }
    printf("\n");
    for (int l = 0; l <= 0xF; l++) {
      uint8_t op = (h << 4) | l;
      op_result r = op_cb(&fd, op);
      printf("%2d %3d     |", r.length, r.duration);
    }
    printf("\n\n");
  }

  return 0;
}