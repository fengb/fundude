#include <stdio.h>
#include "zasm.h"

zasm zasm0(const char* str) {
  return (zasm){str, 0, 0};
}

zasm zasm1(const char* str, zasm_arg arg) {
  return (zasm){str, arg, 0};
}

zasm zasm2(const char* str, zasm_arg arg1, zasm_arg arg2) {
  return (zasm){str, arg1, arg2};
}

zasm zasm_sys_mode(sys_mode m) {
  switch (m) {
    case SYS_NORM: return zasm0("NORM");
    case SYS_HALT: return zasm0("HALT");
    case SYS_STOP: return zasm0("STOP");
    case SYS_FATAL: return zasm0("FATAL");
    default: return zasm0("MODE?");
  }
}

zasm_arg zasma_cond(cond c) {
  return (zasm_arg){ZASM_COND, ZASM_PLAIN, c};
}

zasm_arg zasma_reg8(zasm_format f, fundude* fd, reg8* reg) {
  ptrdiff_t offset = (void*)reg - (void*)&fd->reg;
  return (zasm_arg){ZASM_REG8, f, offset};
}

zasm_arg zasma_reg16(zasm_format f, fundude* fd, reg16* reg) {
  ptrdiff_t offset = (void*)reg - (void*)&fd->reg;
  return (zasm_arg){ZASM_REG16, f, offset};
}

zasm_arg zasma_hex8(zasm_format f, uint8_t val) {
  return (zasm_arg){ZASM_HEX8, f, val};
}

zasm_arg zasma_hex16(zasm_format f, uint16_t val) {
  return (zasm_arg){ZASM_HEX16, f, val};
}

int zasm_snprintf(char* str, size_t size, zasm* zasm) {
  // FIXME
  return sprintf(str, "%s $%04X $%04X", zasm->name, zasm->arg1.val, zasm->arg2.val);
}
