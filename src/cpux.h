#ifndef __CPUX_H
#define __CPUX_H

#include <stdbool.h>
#include "fundude.h"
#include "zasm.h"

typedef struct {
  uint16_t jump;
  int length;
  int duration;
  zasm zasm;
} cpu_result;

cpu_result cpu_step(fundude* fd, uint8_t op[]);

#endif
