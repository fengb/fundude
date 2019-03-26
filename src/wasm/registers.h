#include <stdbool.h>
#include <stdint.h>
#include "memory.h"

typedef struct {
  union {
    uint16_t AF;
    struct {
      uint8_t A;
      uint8_t F;
    };
  };

  union {
    uint16_t BC;
    struct {
      uint8_t B;
      uint8_t C;
    };
  };

  union {
    uint16_t DE;
    struct {
      uint8_t D;
      uint8_t E;
    };
  };

  union {
    uint16_t HL;
    struct {
      uint8_t H;
      uint8_t L;
    };
  };

  uint16_t SP;
  uint16_t PC;
} fd_registers;

typedef struct {
  bool Z;
  bool N;
  bool H;
  bool C;
} fd_flags;

fd_flags get_flags(fd_registers* reg);
uint8_t set_flags(fd_registers* reg, fd_flags f);
