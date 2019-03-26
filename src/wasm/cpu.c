#include <assert.h>
#include "registers.h"

typedef int cycles;

cycles op_noop() {
  return 1;
}

cycles op_ld_wide_d16(uint16_t* reg, uint16_t val) {
  *reg = val;
  return 3;
}

cycles op_ld_awide_narrow(fd_memory* mem, uint16_t* tgt, uint8_t* src) {
  fdm_set(mem, *tgt, *src);
  return 2;
}

uint16_t wide(uint8_t upper, uint8_t lower) {
  return (upper << 8) + lower;
}

cycles run(fd_registers* reg, fd_memory* mem, uint8_t opcode, uint8_t p1, uint8_t p2) {
  switch (opcode) {
    case 0x00: return op_noop();
    case 0x01: return op_ld_wide_d16(&reg->BC, wide(p1, p2));
    case 0x02: return op_ld_awide_narrow(mem, &reg->BC, &reg->A);
    case 0x03: return 0;
    case 0x04: return 0;
    case 0x05: return 0;
    case 0x06: return 0;
    case 0x07: return 0;
    case 0x08: return 0;
    case 0x09: return 0;
    case 0x0A: return 0;
    case 0x0B: return 0;
    case 0x0C: return 0;
    case 0x0D: return 0;
    case 0x0E: return 0;
    case 0x0F: return 0;
  }

  assert(false); // Op not implemented
  return 0;
}

void tick(fd_registers* reg, fd_memory* mem) {
  cycles c = run(reg, mem, fdm_get(mem, reg->PC), fdm_get(mem, reg->PC + 1), fdm_get(mem, reg->PC + 2));
  reg->PC += c;
}
