#include <stdint.h>

typedef union {
  struct {
    uint8_t cartridge[0x8000];
    uint8_t vram[0x2000];
    uint8_t switchable_ram[0x2000];
    uint8_t ram[0x2000];
    uint8_t _ram_echo[0x1E00];
    uint8_t oam[0x00A0];
    uint8_t _empty1[0x0060];
    uint8_t io_ports[0x004C];
    uint8_t _empty2[0x0034];
    uint8_t high_ram[0x007F];
    uint8_t interrupt_enable;
  };
  uint8_t RAW[0x10000];
} fd_memory;

uint8_t* fdm_ptr(fd_memory* m, uint16_t addr);
uint8_t fdm_get(fd_memory* m, uint16_t addr);
void fdm_set(fd_memory* m, uint16_t addr, uint8_t val);
