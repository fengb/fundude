#include "fundude.h"

typedef struct {
  const char* name;
  uint8_t val;
} cb_result;

reg8* cb_tgt(fundude* fd, uint8_t op);
cb_result cb_run(fundude* fd, uint8_t op, uint8_t val);
