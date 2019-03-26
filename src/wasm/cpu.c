#include <assert.h>
#include "memory.h"
#include "registers.h"

typedef struct {
  fd_registers reg;
  fd_memory mem;
} fd_cpu;

uint16_t w2(uint8_t op[]) {
  return (op[1] << 8) + op[2];
}

bool will_overflow(uint8_t a, uint8_t b) {
  return a > UINT8_MAX - b;
}

bool will_underflow(uint8_t a, uint8_t b) {
  return a < b;
}

typedef int cycles;

/* These functions are a lot more scannable if the names line up, hence the cryptic abbreviations:
     rr -- register (8bit)
     ww -- wide register (16bit)
     08 -- byte literal (8bit)
     16 -- double-byte literal (16bit)

     RR -- register address (8bit + $FF00)
     WW -- wide register address (16bit)
     0A -- byte address (8bit + $FF00)
     1F -- double-byte address (16bit)
*/

cycles op_nop() {
  return 1;
}

cycles op_rlc_rr___(fd_cpu* _, reg8* tgt) {
  int msb = tgt->_ >> 7 & 1;
  tgt->_ = tgt->_ << 1 | msb;
  return 1;
}

cycles op_lod_rr_08(fd_cpu* _, reg8* tgt, uint8_t d8) {
  tgt->_ = d8;
  return 2;
}

cycles op_lod_ww_16(fd_cpu* _, reg16* tgt, uint16_t d16) {
  tgt->_ = d16;
  return 3;
}

cycles op_lod_WW_rr(fd_cpu* cpu, reg16* tgt, reg8* src) {
  fdm_set(&cpu->mem, tgt->_, src->_);
  return 2;
}

cycles op_lod_1F_ww(fd_cpu* cpu, uint16_t a16, reg16* src) {
  fdm_set(&cpu->mem, a16, src->_);
  return 3;
}

cycles op_inc_ww___(fd_cpu* _, reg16* tgt) {
  tgt->_++;
  return 2;
}

cycles op_add_rr_08(fd_cpu* cpu, reg8* tgt, uint8_t val) {
  fd_flags f = fd_get_flags(&cpu->reg);
  f.N = false;
  f.H = will_overflow(tgt->_, val);
  tgt->_ += val;
  f.Z = tgt->_ == 0;
  fd_set_flags(&cpu->reg, f);
  return 1;
}

cycles op_sub_rr_08(fd_cpu* cpu, reg8* tgt, uint8_t val) {
  fd_flags f = fd_get_flags(&cpu->reg);
  f.N = true;
  f.H = will_underflow(tgt->_, val);
  tgt->_ -= val;
  f.Z = tgt->_ == 0;
  fd_set_flags(&cpu->reg, f);
  return 1;
}

cycles op_inc_rr___(fd_cpu* cpu, reg8* tgt) {
  return op_add_rr_08(cpu, tgt, 1);
}

cycles op_dec_rr___(fd_cpu* cpu, reg8* tgt) {
  return op_sub_rr_08(cpu, tgt, 1);
}

cycles run(fd_cpu* cpu, uint8_t op[]) {
  switch (op[0]) {
    case 0x00: return op_nop();
    case 0x01: return op_lod_ww_16(cpu, &cpu->reg.BC, w2(op));
    case 0x02: return op_lod_WW_rr(cpu, &cpu->reg.BC, &cpu->reg.A);
    case 0x03: return op_inc_ww___(cpu, &cpu->reg.BC);
    case 0x04: return op_inc_rr___(cpu, &cpu->reg.B);
    case 0x05: return op_dec_rr___(cpu, &cpu->reg.B);
    case 0x06: return op_lod_rr_08(cpu, &cpu->reg.B, op[1]);
    case 0x07: return op_rlc_rr___(cpu, &cpu->reg.A);
    case 0x08: return op_lod_1F_ww(cpu, w2(op), &cpu->reg.SP);
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

void tick(fd_cpu* cpu) {
  cycles c = run(cpu, fdm_ptr(&cpu->mem, cpu->reg.PC._));
  cpu->reg.PC._ += c;
}
