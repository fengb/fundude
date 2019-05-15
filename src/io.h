#include <stdbool.h>
#include <stdint.h>
#include "apu.h"
#include "irq.h"
#include "joypad.h"
#include "lpt.h"
#include "ppu.h"
#include "timer.h"

typedef union {
  uint8_t RAW[0x4C];
  struct {
    joypad_io P1;
    lpt_io lpt;  // $FF01-FF02
    uint8_t _pad_ff03;
    timer_io timer;
    uint8_t _pad_ff08_0e[7];
    irq_flags IF;  // FF0F

    apu_io apu;
    ppu_io ppu;
  };
} io;
