#include "timerx.h"

static int tima_interval(io_timer_speed t) {
  switch (t) {
    case IO_TIMER_SPEED_4096: return 1024;
    case IO_TIMER_SPEED_16384: return 256;
    case IO_TIMER_SPEED_65536: return 64;
    case IO_TIMER_SPEED_262144: return 16;
    default: return INT16_MAX;
  }
}

static uint16_t step_up(int interval, int base, int add) {
  return (base + add) / interval - base / interval;
}

void io_step(fundude* fd, uint8_t cycles) {
  if (!fd->mmu.io_ports.TAC.active) {
    return;
  }

  uint8_t start = fd->mmu.io_ports.TIMA;
  fd->mmu.io_ports.TIMA +=
      step_up(tima_interval(fd->mmu.io_ports.TAC.speed), fd->clock.timer, cycles);
  if (fd->mmu.io_ports.TIMA < start) {
    // Overflow!
    // TODO: these effects actually happen 1 cycle later
    fd->mmu.io_ports.TIMA += fd->mmu.io_ports.TMA;
    // IF interrupt
  }

  fd->clock.timer += cycles;  // overflow is fine
  fd->mmu.io_ports.DIV = fd->clock.timer / 256;
}
