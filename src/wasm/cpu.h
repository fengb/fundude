#include <stdbool.h>
#include "debug.h"
#include "fundude.h"

typedef struct {
  uint16_t next;
  int length;
  int duration;
#ifndef NDEBUG
  db_str op_name;
#endif
} op_result;

bool will_carry_from(int bit, int a, int b);
bool will_borrow_from(int bit, int a, int b);

void fd_tick(fundude* fd);
op_result fd_run(fundude* fd, uint8_t op[]);

#ifndef NDEBUG
#define OP_JUMP(next, length, duration, ...) \
  ((op_result){next, (length), (duration), db_printf(__VA_ARGS__)})
#else
#define OP_JUMP(fd, length, duration, ...) \
  ((op_result){next, (length), (duration)})
#endif

#define OP_STEP(fd, length, ...) \
  OP_JUMP(fd->reg.PC._ + (length), (length), __VA_ARGS__)
