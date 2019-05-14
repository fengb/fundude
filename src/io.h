#include <stdbool.h>
#include <stdint.h>
#include "apu.h"
#include "intr.h"
#include "ppu.h"
#include "timer.h"

typedef union {
  uint8_t RAW[0x4C];
  struct {
    union {
      uint8_t _;
      struct {
        bool P10 : 1;
        bool P11 : 1;
        bool P12 : 1;
        bool P13 : 1;
        bool P14 : 1;
        bool P15 : 1;
        uint8_t _padding : 2;
      };
    } P1;
    uint8_t SB;  // $FF01
    uint8_t SC;  // $FF02
    uint8_t _pad_ff03;
    timer_io timer;
    uint8_t _pad_ff08_0e[7];
    intr_flags IF;  // FF0F

    apu_io apu;
    ppu_io ppu;
  };
} io;
