#include "debug.h"
#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>

db_str db_printf(char* fmt, ...) {
  db_str s;
  va_list args;
  va_start(args, fmt);
  vsnprintf(s._, sizeof(db_str), fmt, args);
  va_end(args);
  return s;
}

char* db_cond(cond c) {
  switch (c) {
    case COND_NZ: return "NZ";
    case COND_Z: return "Z";
    case COND_NC: return "NC";
    case COND_C: return "C";
    default: return "?";
  }
}

char* db_reg8(fundude* fd, reg8* reg) {
  switch ((void*)reg - (void*)&fd->reg) {
    case offsetof(fd_registers, A): return "A";
    case offsetof(fd_registers, F): return "F";
    case offsetof(fd_registers, B): return "B";
    case offsetof(fd_registers, C): return "C";
    case offsetof(fd_registers, D): return "D";
    case offsetof(fd_registers, E): return "E";
    case offsetof(fd_registers, H): return "H";
    case offsetof(fd_registers, L): return "L";
  }

  return "??";
}

char* db_reg16(fundude* fd, reg16* reg) {
  switch ((void*)reg - (void*)&fd->reg) {
    case offsetof(fd_registers, AF): return "AF";
    case offsetof(fd_registers, BC): return "BC";
    case offsetof(fd_registers, DE): return "DE";
    case offsetof(fd_registers, HL): return "HL";
    case offsetof(fd_registers, SP): return "SP";
    case offsetof(fd_registers, PC): return "PC";
  }

  return "??";
}
