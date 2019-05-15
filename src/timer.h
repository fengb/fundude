#include <stdint.h>

typedef enum __attribute__((__packed__)) {
  TIMER_SPEED_4096 = 0,
  TIMER_SPEED_262144 = 1,
  TIMER_SPEED_65536 = 2,
  TIMER_SPEED_16384 = 3,
} timer_speed;

typedef struct {
  uint8_t DIV;   // $FF04
  uint8_t TIMA;  // $FF05
  uint8_t TMA;   // $FF06
  struct {
    timer_speed speed : 2;
    bool active : 1;
  } TAC;
} timer_io;
