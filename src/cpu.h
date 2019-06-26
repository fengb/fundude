#ifndef __CPU_H
#define __CPU_H

#include <stdbool.h>
#include <stdint.h>

#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#error
#endif

typedef enum {
  CPU_COND_NZ,
  CPU_COND_Z,
  CPU_COND_NC,
  CPU_COND_C,
} cpu_cond;

typedef struct {
  uint8_t _;
} cpu_reg8;

typedef union {
  uint16_t _;
  struct {
    cpu_reg8 _1;
    cpu_reg8 _0;
  } x;
} cpu_reg16;

typedef struct {
  cpu_reg16 AF;
  cpu_reg16 BC;
  cpu_reg16 DE;
  cpu_reg16 HL;
  cpu_reg16 SP;
  cpu_reg16 PC;
} cpu;

#endif
