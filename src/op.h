#ifndef __OP_H
#define __OP_H

#include <stdbool.h>
#include "fundude.h"
#include "zasm.h"

typedef struct {
  uint16_t jump;
  int length;
  int duration;
  zasm zasm;
} op_result;

void op_run(fundude* fd, uint32_t µs);
op_result op_tick(fundude* fd, uint8_t op[]);

#endif
