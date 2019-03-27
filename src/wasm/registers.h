#include <stdbool.h>
#include <stdint.h>

typedef struct {
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
  unsigned int _padding : 4;
  bool C : 1;
  bool H : 1;
  bool N : 1;
  bool Z : 1;
#else
  bool Z : 1;
  bool N : 1;
  bool H : 1;
  bool C : 1;
  unsigned int _padding : 4;
#endif
} fd_flags;

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
      union {
        reg8 F;
        fd_flags FLAGS;
      };
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
