#ifndef __GBA_H
#define __GBA_H

#include <stdint.h>
#include "base.h"
#include "cpu.h"

typedef enum {
  ZASM_NONE,
  ZASM_COND,
  ZASM_SYS_MODE,
  ZASM_REG8,
  ZASM_REG16,
  ZASM_HEX8,
  ZASM_HEX16,
} zasm_type;

typedef enum {
  ZASM_PLAIN,
  ZASM_PAREN,
  ZASM_HIMEM,
} zasm_format;

typedef struct {
  zasm_type type;
  zasm_format format;
  uint16_t val;
} zasm_arg;

typedef struct {
  const char* name;
  zasm_arg arg1;
  zasm_arg arg2;
} zasm;

zasm zasm0(const char* m);
zasm zasm1(const char* m, zasm_arg arg);
zasm zasm2(const char* m, zasm_arg arg1, zasm_arg arg2);

zasm_arg zasma_cond(cpu_cond c);
zasm_arg zasma_sys_mode(sys_mode m);
zasm_arg zasma_reg8(zasm_format f, fundude* fd, cpu_reg8* reg);
zasm_arg zasma_reg16(zasm_format f, fundude* fd, cpu_reg16* reg);
zasm_arg zasma_hex8(zasm_format f, uint8_t val);
zasm_arg zasma_hex16(zasm_format f, uint16_t val);

int zasm_puts(char* out, size_t limit, zasm z);

#endif
