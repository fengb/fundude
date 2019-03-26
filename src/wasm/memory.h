#include <stdint.h>

#define KB 1024

typedef struct {
  uint8_t cartridge[32 * KB];
  uint8_t ram[8 * KB];
  uint8_t vram[8 * KB];
  uint8_t oam[40 * 4];
} fd_memory;

uint8_t* fdm_ptr(fd_memory* m, uint16_t addr);
uint8_t fdm_get(fd_memory* m, uint16_t addr);
void fdm_set(fd_memory* m, uint16_t addr, uint8_t val);
