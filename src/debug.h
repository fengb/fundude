#include "op.h"
#include "fundude.h"
#include "str.h"

str db_sprintf(char* fmt, ...);

char* db_cond(cond c);

char* db_reg8(fundude* fd, reg8* reg);
char* db_reg16(fundude* fd, reg16* reg);
