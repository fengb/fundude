#include <stdbool.h>
#include <stdint.h>
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

    uint8_t NR10;  // $FF10
    uint8_t NR11;  // $FF11
    uint8_t NR12;  // $FF12
    uint8_t NR13;  // $FF13
    uint8_t NR14;  // $FF14
    uint8_t NR21;  // $FF15
    uint8_t NR22;  // $FF16
    uint8_t NR23;  // $FF17
    uint8_t NR24;  // $FF18
    uint8_t _pad_ff1a;
    uint8_t NR30;  // $FF1A
    uint8_t NR31;  // $FF1B
    uint8_t NR32;  // $FF1C
    uint8_t NR33;  // $FF1D
    uint8_t NR34;  // $FF1E
    uint8_t _pad_ff1f;

    uint8_t NR41;  // $FF20
    uint8_t NR42;  // $FF21
    uint8_t NR43;  // $FF22
    uint8_t NR44;  // $FF23
    uint8_t NR50;  // $FF24
    uint8_t NR51;  // $FF25
    uint8_t NR52;  // $FF26
    uint8_t _pad_ff27_2f[9];

    uint8_t wave_pattern[0x10];  // $FF30 - FF3F

    ppu_io ppu;
  };
} io;
