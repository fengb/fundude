#include "debug.h"
#include <stdarg.h>
#include <stdio.h>

db_str db_printf(char* fmt, ...) {
  db_str s;
  va_list args;
  va_start(args, fmt);
  snprintf(s._, sizeof(db_str), fmt, args);
  va_end(args);
  return s;
}
