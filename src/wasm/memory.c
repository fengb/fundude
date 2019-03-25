#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include "memory.h"

uint8_t* fdm_ptr(fd_memory* m, uint16_t addr) {
  if (addr < 0x8000) {
    return &m->cartridge[addr];
  } else if (addr < 0xA000) {
    return &m->vram[addr - 0x8000];
  } else if (addr < 0xC000) {
    return 0; // switchable RAM bank
  } else if (addr < 0xE000) {
    return &m->ram[addr - 0xC000];
  } else if (addr < 0xFE00) {
    return &m->ram[addr - 0xE000]; // Echo of 8kB Internal RAM
  } else if (addr < 0xFEA0) {
    return &m->oam[addr - 0xFE00];
  } else if (addr < 0xFF00) {
    return 0; // Empty but unusable for I/O
  } else if (addr < 0xFF4C) {
    return 0; // I/O ports
  } else if (addr < 0xFF80) {
    return 0; // Empty but unusable for I/O
  } else if (addr < 0xFFFF) {
    return 0; // Internal RAM
  } else if (addr == 0xFFFF) {
    return 0; // Interrupt enable register
  }

  assert(false); // Unmatched
  return 0;
}

uint8_t fdm_get(fd_memory* m, uint16_t addr) {
  uint8_t* ptr = fdm_ptr(m, addr);
  assert(ptr != NULL);
  return *ptr;
}

uint8_t* fdm_set(fd_memory* m, uint16_t addr, uint8_t val) {
  uint8_t* ptr = fdm_ptr(m, addr);
  assert(ptr != NULL);
  *ptr = val;
  return ptr;
}
