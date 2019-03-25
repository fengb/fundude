#include <stdbool.h>
#include <stdint.h>

typedef union {
  uint16_t pair;
  uint8_t _[2];
} fd_register;

typedef struct {
  fd_register AF;
  fd_register BC;
  fd_register DE;
  fd_register HL;
  fd_register SP;
  fd_register PC;
} fd_cpu;

typedef struct {
  bool Z;
  bool N;
  bool H;
  bool C;
} fd_flags;

fd_flags to_flags(uint8_t reg8);
uint8_t from_flags(fd_flags);
