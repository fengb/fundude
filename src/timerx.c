#include "timerx.h"

typedef enum __attribute__((__packed__)) {
  TIMER_SPEED_4096 = 0,
  TIMER_SPEED_262144 = 1,
  TIMER_SPEED_65536 = 2,
  TIMER_SPEED_16384 = 3,
} timer_speed;

typedef union {
  uint8_t _;
  struct {
    timer_speed speed : 2;
    bool active : 1;
  };
} HACK_TAC;

static uint8_t tima_shift(timer_speed t, uint8_t cycles) {
  switch (t) {
    case TIMER_SPEED_4096: return cycles * 256 / 1024;  // every 1024 cycles
    case TIMER_SPEED_16384: return cycles * 256 / 256;  // every 256 cycles
    case TIMER_SPEED_65536: return cycles * 256 / 64;   // every 64 cycles
    case TIMER_SPEED_262144: return cycles * 256 / 16;  // every 16 cycles
    default: return 1;
  }
}

void timer_step(fundude* fd, uint8_t cycles) {
  HACK_TAC tac = {._ = fd->mmu.io.timer.TAC};

  fd->clock.timer += cycles;  // overflow is fine
  fd->mmu.io.timer.DIV = fd->clock.timer / 256;

  if (!tac.active) {
    return;
  }

  uint8_t start = fd->mmu.io.timer.TIMA;

  fd->mmu.io.timer.TIMA += tima_shift(tac.speed, cycles);

  // if overflowed
  if (fd->mmu.io.timer.TIMA < start) {
    // TODO: this effect actually happen 1 cycle later
    fd->mmu.io.timer.TIMA += fd->mmu.io.timer.TMA;
    // fd->mmu.io.IF.timer = true;
  }
}
