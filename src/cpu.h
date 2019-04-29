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
  uint8_t _padding : 4;
  bool C : 1;
  bool H : 1;
  bool N : 1;
  bool Z : 1;
} cpu_flags;

typedef struct {
  uint8_t _;
} cpu_reg8;

typedef struct {
  uint16_t _;
} cpu_reg16;

typedef struct {
  union {
    cpu_reg16 AF;
    struct {
      union {
        cpu_reg8 F;
        cpu_flags FLAGS;
      };
      cpu_reg8 A;
    };
  };

  union {
    cpu_reg16 BC;
    struct {
      cpu_reg8 C;
      cpu_reg8 B;
    };
  };

  union {
    cpu_reg16 DE;
    struct {
      cpu_reg8 E;
      cpu_reg8 D;
    };
  };

  union {
    cpu_reg16 HL;
    struct {
      cpu_reg8 L;
      cpu_reg8 H;
    };
  };

  cpu_reg16 SP;
  cpu_reg16 PC;
} cpu;

#endif
