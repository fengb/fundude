#include "fundude.h"

typedef struct {
  char _[64];
} db_str;

db_str db_printf(char* fmt, ...);

char* db_reg8(fundude* fd, reg8* reg);
char* db_reg16(fundude* fd, reg16* reg);
