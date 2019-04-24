#include <stddef.h>
#include <stdint.h>
#include "display.h"
#include "io.h"

#define BEYOND_BOOTLOADER 0x100
#define BEYOND_CART 0x8000

extern uint8_t BOOTLOADER[0x100];

typedef struct {
  union {
    uint8_t RAW[0x8000];
    struct {
      fd_vram vram;                    // 0x8000 - 0xA000
      uint8_t switchable_ram[0x2000];  // 0xA000 - 0xC000
      uint8_t ram[0x2000];             // 0xC000 - 0xE000
      uint8_t _pad_ram_echo[0x1E00];   // 0xE000 - 0xFE00
      sprite_attr oam[40];             // 0xFE00 - 0xFEA0
      uint8_t _pad_fea0_ff00[0x0060];  // 0xFEA0 - 0xFF00
      fd_io io_ports;                  // 0xFF00 - 0xFF4C
      uint8_t _pad_ff4d_4f[0x0004];    //
      uint8_t boot_complete;           // 0xFF50 Bootloader sets this on 0xFE
      uint8_t _pad_ff51_80[0x002F];    // 0xFF51 - 0xFF80
      uint8_t high_ram[0x007F];        // 0xFF80 - 0xFFFF
      uint8_t interrupt_enable;        // 0xFFFF
    };
  };

  size_t cart_length;
  uint8_t* cart;  // 0x0000 - 0x8000
} fd_memory;

uint8_t* fdm_ptr(fd_memory* m, uint16_t addr);
uint8_t fdm_get(fd_memory* m, uint16_t addr);
void fdm_set(fd_memory* m, uint16_t addr, uint8_t val);
