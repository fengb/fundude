#include <stdbool.h>
#include "debug.h"
#include "fundude.h"

typedef struct {
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
#define OP_RESULT(length, duration, ...) ((op_result){length, duration, db_printf(__VA_ARGS__)})
#else
#define OP_RESULT(length, duration, ...) ((op_result){length, duration})
#endif
