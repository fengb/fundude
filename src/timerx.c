#include "timerx.h"

static int tima_shift(io_timer_speed t) {
  switch (t) {
    case IO_TIMER_SPEED_4096: return 1024;  // 2 ** 10
    case IO_TIMER_SPEED_16384: return 256;  // 2 ** 8
    case IO_TIMER_SPEED_65536: return 64;   // 2 ** 6
    case IO_TIMER_SPEED_262144: return 16;  // 2 ** 4
    default: return INT16_MAX;
  }
}

static uint16_t step_up(int shift, int base, int add) {
  return ((base + add) >> shift) - (base >> shift);
}

void timer_step(fundude* fd, uint8_t cycles) {
  if (!fd->mmu.io_ports.TAC.active) {
    return;
  }

  uint8_t start = fd->mmu.io_ports.TIMA;
  fd->mmu.io_ports.TIMA += step_up(tima_shift(fd->mmu.io_ports.TAC.speed), fd->clock.timer, cycles);
  if (fd->mmu.io_ports.TIMA < start) {
    // TODO: this effect actually happen 1 cycle later
    fd->mmu.io_ports.TIMA += fd->mmu.io_ports.TMA;
    fd->mmu.io_ports.IF.vblank = true;
  }

  fd->clock.timer += cycles;  // overflow is fine
  fd->mmu.io_ports.DIV = fd->clock.timer / 256;
}
