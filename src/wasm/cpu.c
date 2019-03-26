#include <assert.h>
#include "registers.h"

typedef int cycles;

cycles op_noop() {
  return 1;
}

cycles op_ld_wide_d16(reg16* tgt, uint16_t val) {
  tgt->_ = val;
  return 3;
}

cycles op_ld_awide_narrow(fd_memory* mem, reg16* tgt, reg8* src) {
  fdm_set(mem, tgt->_, src->_);
  return 2;
}

uint16_t wide(uint8_t upper, uint8_t lower) {
  return (upper << 8) + lower;
}

cycles run(fd_registers* reg, fd_memory* mem, uint8_t op[]) {
  switch (op[0]) {
    case 0x00: return op_noop();
    case 0x01: return op_ld_wide_d16(&reg->BC, wide(op[1], op[2]));
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
  cycles c = run(reg, mem, fdm_ptr(mem, reg->PC._));
  reg->PC._ += c;
}
