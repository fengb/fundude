#ifndef __MMU_H
#define __MMU_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "apu.h"
#include "ggp.h"
#include "irq.h"
#include "lpt.h"
#include "ppu.h"
#include "timer.h"

typedef struct {
  ggp_io P1;                     // [$FF00]
  lpt_io lpt;                    // [$FF01 - $FF02]
  uint8_t _pad_ff03;             // [$FF03]
  timer_io timer;                // [$FF04 - $FF07]
  uint8_t _pad_ff08_0e[7];       // [$FF08 - $FF0E]
  irq_flags IF;                  // [$FF0F]
  apu_io apu;                    // [$FF10 - $FF3F]
  ppu_io ppu;                    // [$FF40 - $FF4C]
  uint8_t _pad_ff4d_4f[0x0004];  // [$FF4D - $FF4F]
  uint8_t boot_complete;         // [$FF50] Bootloader sets this on 0x00FE
  uint8_t _pad_ff51_7f[0x002F];  // [$FF51 - $FF7f]
} mmu_io;

typedef struct {
  union {
    uint8_t RAW[0x8000];
    struct {
      ppu_vram vram;                   // [$8000 - $A000)
      uint8_t switchable_ram[0x2000];  // [$A000 - $C000)
      uint8_t ram[0x2000];             // [$C000 - $E000)
      uint8_t _pad_ram_echo[0x1E00];   // [$E000 - $FE00)
      ppu_sprite_attr oam[40];         // [$FE00 - $FEA0)
      uint8_t _pad_fea0_ff00[0x0060];  // [$FEA0 - $FF00)
      mmu_io io;                       // [$FF00 - $FF80)
      uint8_t high_ram[0x007F];        // [$FF80 - $FFFF)
      irq_flags interrupt_enable;      // [$FFFF]
    };
  };

  size_t cart_length;
  uint8_t* cart;  // 0x0000 - 0x8000
} mmu;

#endif
