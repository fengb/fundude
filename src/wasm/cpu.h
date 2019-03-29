#include <stdbool.h>
#include "fundude.h"

typedef struct {
  int length;
  int duration;
} instr;

bool will_carry_from(int bit, int a, int b);
bool will_borrow_from(int bit, int a, int b);

void fd_tick(fundude* fd);
instr fd_run(fundude* fd, uint8_t op[]);
