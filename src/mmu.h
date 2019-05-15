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
  ggp_io P1;
  lpt_io lpt;  // $FF01-FF02
  uint8_t _pad_ff03;
  timer_io timer;
  uint8_t _pad_ff08_0e[7];
  irq_flags IF;  // $FF0F

  apu_io apu;
  ppu_io ppu;
} mmu_io;

typedef struct {
  union {
    uint8_t RAW[0x8000];
    struct {
      ppu_vram vram;                   // 0x8000 - 0xA000
      uint8_t switchable_ram[0x2000];  // 0xA000 - 0xC000
      uint8_t ram[0x2000];             // 0xC000 - 0xE000
      uint8_t _pad_ram_echo[0x1E00];   // 0xE000 - 0xFE00
      ppu_sprite_attr oam[40];         // 0xFE00 - 0xFEA0
      uint8_t _pad_fea0_ff00[0x0060];  // 0xFEA0 - 0xFF00
      mmu_io io;                       // 0xFF00 - 0xFF4C
      uint8_t _pad_ff4d_4f[0x0004];    //
      uint8_t boot_complete;           // 0xFF50 Bootloader sets this on 0xFE
      uint8_t _pad_ff51_80[0x002F];    // 0xFF51 - 0xFF80
      uint8_t high_ram[0x007F];        // 0xFF80 - 0xFFFF
      irq_flags interrupt_enable;      // 0xFFFF
    };
  };

  size_t cart_length;
  uint8_t* cart;  // 0x0000 - 0x8000
} mmu;

#endif
