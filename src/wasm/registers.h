#include <stdbool.h>
#include <stdint.h>
#include "memory.h"

typedef struct {
  uint8_t _;
} reg8;

typedef struct {
  uint16_t _;
} reg16;

typedef struct {
  union {
    reg16 AF;
    struct {
      reg8 A;
      reg8 F;
    };
  };

  union {
    reg16 BC;
    struct {
      reg8 B;
      reg8 C;
    };
  };

  union {
    reg16 DE;
    struct {
      reg8 D;
      reg8 E;
    };
  };

  union {
    reg16 HL;
    struct {
      reg8 H;
      reg8 L;
    };
  };

  reg16 SP;
  reg16 PC;
} fd_registers;

typedef struct {
  bool Z;
  bool N;
  bool H;
  bool C;
} fd_flags;

fd_flags get_flags(fd_registers* reg);
uint8_t set_flags(fd_registers* reg, fd_flags f);
