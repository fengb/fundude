#ifndef __GBASM_H
#define __GBASM_H

#include <stdint.h>
#include "fundude.h"
#include "registers.h"

typedef enum {
  GBASM_NONE,
  GBASM_COND,
  GBASM_REG8,
  GBASM_REG16,
  GBASM_REG8A,
  GBASM_REG16A,
  GBASM_UINT8,
  GBASM_UINT16,
  GBASM_UINT8A,
  GBASM_UINT16A,
} gbasm_type;

typedef struct {
  gbasm_type type : 16;  // force 2 byte alignment
  uint16_t val;
} gbasm_arg;

typedef struct {
  const char* name;
  gbasm_arg arg1;
  gbasm_arg arg2;
} gbasm;

gbasm gbasm0(const char* m);
gbasm gbasm1(const char* m, gbasm_arg arg);
gbasm gbasm2(const char* m, gbasm_arg arg1, gbasm_arg arg2);
gbasm gbasm_sys_mode(sys_mode m);

gbasm_arg gbasma_cond(cond c);
gbasm_arg gbasma_reg8(fundude* fd, reg8* reg);
gbasm_arg gbasma_reg16(fundude* fd, reg16* reg);
gbasm_arg gbasma_reg8a(fundude* fd, reg8* reg);
gbasm_arg gbasma_reg16a(fundude* fd, reg16* reg);
gbasm_arg gbasma_uint8(uint8_t val);
gbasm_arg gbasma_uint8a(uint8_t val);
gbasm_arg gbasma_uint16(uint16_t val);
gbasm_arg gbasma_uint16a(uint16_t val);

// TODO: don't pass pointer
int gbasm_snprintf(char* str, size_t size, gbasm* gb);

#endif
