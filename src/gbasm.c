#include "gbasm.h"
#include <stdio.h>

gbasm gbasm0(const char* str) {
  return (gbasm){str, 0, 0};
}

gbasm gbasm1(const char* str, gbasm_arg arg) {
  return (gbasm){str, arg, 0};
}

gbasm gbasm2(const char* str, gbasm_arg arg1, gbasm_arg arg2) {
  return (gbasm){str, arg1, arg2};
}

gbasm gbasm_sys_mode(sys_mode m) {
  switch (m) {
    case SYS_NORM: return gbasm0("NORM");
    case SYS_HALT: return gbasm0("HALT");
    case SYS_STOP: return gbasm0("STOP");
    case SYS_FATAL: return gbasm0("FATAL");
    default: return gbasm0("MODE?");
  }
}

gbasm_arg gbasma_cond(cond c) {
  return (gbasm_arg){GBASM_COND, c};
}

gbasm_arg gbasma_reg8(fundude* fd, reg8* reg) {
  ptrdiff_t offset = (void*)reg - (void*)&fd->reg;
  return (gbasm_arg){GBASM_REG8, offset};
}

gbasm_arg gbasma_reg8a(fundude* fd, reg8* reg) {
  ptrdiff_t offset = (void*)reg - (void*)&fd->reg;
  return (gbasm_arg){GBASM_REG8A, offset};
}

gbasm_arg gbasma_reg16(fundude* fd, reg16* reg) {
  ptrdiff_t offset = (void*)reg - (void*)&fd->reg;
  return (gbasm_arg){GBASM_REG16, offset};
}

gbasm_arg gbasma_reg16a(fundude* fd, reg16* reg) {
  ptrdiff_t offset = (void*)reg - (void*)&fd->reg;
  return (gbasm_arg){GBASM_REG16A, offset};
}

gbasm_arg gbasma_uint8(uint8_t val) {
  return (gbasm_arg){GBASM_UINT8, val};
}

gbasm_arg gbasma_uint8a(uint8_t val) {
  return (gbasm_arg){GBASM_UINT8A, val};
}

gbasm_arg gbasma_uint16(uint16_t val) {
  return (gbasm_arg){GBASM_UINT16, val};
}

gbasm_arg gbasma_uint16a(uint16_t val) {
  return (gbasm_arg){GBASM_UINT16A, val};
}

int gbasm_snprintf(char* str, size_t size, gbasm* gb) {
  // FIXME
  return sprintf(str, "%s $%04X $%04X", gb->name, gb->arg1.val, gb->arg2.val);
}
