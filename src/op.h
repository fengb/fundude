#ifndef __OP_H
#define __OP_H

#include <stdbool.h>
#include "fundude.h"
#include "gbasm.h"

typedef struct {
  uint16_t jump;
  int length;
  int duration;
  gbasm gb;
} op_result;

void op_run(fundude* fd, uint32_t µs);
op_result op_tick(fundude* fd, uint8_t op[]);

#endif
