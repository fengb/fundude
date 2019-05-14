#include "timerx.h"

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
  fd->clock.timer += cycles;  // overflow is fine
  fd->mmu.io_ports.timer.DIV = fd->clock.timer / 256;

  if (!fd->mmu.io_ports.timer.TAC.active) {
    return;
  }

  uint8_t start = fd->mmu.io_ports.timer.TIMA;

  fd->mmu.io_ports.timer.TIMA += tima_shift(fd->mmu.io_ports.timer.TAC.speed, cycles);

  // if overflowed
  if (fd->mmu.io_ports.timer.TIMA < start) {
    // TODO: this effect actually happen 1 cycle later
    fd->mmu.io_ports.timer.TIMA += fd->mmu.io_ports.timer.TMA;
    fd->mmu.io_ports.IF.timer = true;
  }
}
