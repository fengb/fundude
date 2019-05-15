#include <stdint.h>

// LPT -- because COM is ambiguous

typedef struct {
  uint8_t SB;  // $FF01
  uint8_t SC;  // $FF02
} lpt_io;
