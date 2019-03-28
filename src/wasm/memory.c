#include "memory.h"
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>

uint8_t* fdm_ptr(fd_memory* mem, uint16_t addr) {
  if (addr < 0x8000) {
    return mem->cartridge;
  } else if (0xE000 <= addr && addr < 0xFE00) {
    // Echo of 8kB Internal RAM
    return &mem->ram[addr - 0xE000];
  } else {
    return &mem->RAW[addr];
  }
}

uint8_t fdm_get(fd_memory* m, uint16_t addr) {
  uint8_t* ptr = fdm_ptr(m, addr);
  assert(ptr != NULL);
  return *ptr;
}

void fdm_set(fd_memory* m, uint16_t addr, uint8_t val) {
  uint8_t* ptr = fdm_ptr(m, addr);
  assert(ptr != NULL);
  *ptr = val;
}
