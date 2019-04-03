#ifndef __OP_H
#define __OP_H

#include <stdbool.h>
#include "fundude.h"
#include "str.h"

typedef struct {
  uint16_t jump;
  int length;
  int duration;
#ifndef NDEBUG
  str op_name;
#endif
} op_result;

typedef enum {
  COND_NZ,
  COND_Z,
  COND_NC,
  COND_C,
} cond;

void op_tick(fundude* fd);
op_result op_run(fundude* fd, uint8_t op[]);

#ifndef NDEBUG
#define OP_JUMP(jump, length, duration, ...) \
  ((op_result){jump, (length), (duration), db_sprintf(__VA_ARGS__)})
#else
#define OP_JUMP(fd, length, duration, ...) \
  ((op_result){jump, (length), (duration)})
#endif

#define OP_STEP(fd, length, ...) \
  OP_JUMP(fd->reg.PC._ + (length), (length), __VA_ARGS__)

#endif
