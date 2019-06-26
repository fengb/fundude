#include <stdint.h>

typedef struct {
  uint8_t DIV;   // $FF04
  uint8_t TIMA;  // $FF05
  uint8_t TMA;   // $FF06
  uint8_t TAC;   // $FF07
} timer_io;
