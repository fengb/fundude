#ifndef __CPUX_H
#define __CPUX_H

#include <stdbool.h>
#include "base.h"
#include "zasm.h"

typedef struct {
  uint16_t jump;
  uint16_t length;
  uint8_t duration;
  zasm zasm;
} cpu_result;

cpu_result cpu_step(fundude* fd, uint8_t op[]);

#endif
