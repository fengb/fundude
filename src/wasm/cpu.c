#include <assert.h>
#include "memory.h"
#include "registers.h"

typedef struct {
  fd_registers reg;
  fd_memory mem;
} fd_cpu;

typedef struct {
  int length;
  int duration;
} instr;

#define INSTR(length, duration) ((instr){length, duration})

uint16_t w2(uint8_t op[]) {
  return (op[1] << 8) + op[2];
}

bool will_overflow(uint8_t a, uint8_t b) {
  return a > UINT8_MAX - b;
}

bool will_underflow(uint8_t a, uint8_t b) {
  return a < b;
}

/* op_ functions are a lot more scannable if the names line up, hence the
   cryptic abbreviations:

     rr -- register (8bit)
     ww -- wide register (16bit)
     08 -- byte literal (8bit)
     16 -- double-byte literal (16bit)

     RR -- register address (8bit + $FF00)
     WW -- wide register address (16bit)
     0A -- byte address (8bit + $FF00)
     1F -- double-byte address (16bit)
*/

instr op_nop() {
  return INSTR(1, 4);
}

instr op_rlc_rr___(fd_cpu* _, reg8* tgt) {
  int msb = tgt->_ >> 7 & 1;
  tgt->_ = tgt->_ << 1 | msb;
  return INSTR(1, 4);
}

instr op_lod_rr_08(fd_cpu* _, reg8* tgt, uint8_t d8) {
  tgt->_ = d8;
  return INSTR(2, 8);
}

instr op_lod_ww_16(fd_cpu* _, reg16* tgt, uint16_t d16) {
  tgt->_ = d16;
  return INSTR(3, 12);
}

instr op_lod_WW_rr(fd_cpu* cpu, reg16* tgt, reg8* src) {
  fdm_set(&cpu->mem, tgt->_, src->_);
  return INSTR(1, 8);
}

instr op_lod_1F_ww(fd_cpu* cpu, uint16_t a16, reg16* src) {
  fdm_set(&cpu->mem, a16, src->_);
  return INSTR(3, 20);
}

instr op_inc_ww___(fd_cpu* _, reg16* tgt) {
  tgt->_++;
  return INSTR(1, 8);
}

instr op_add_rr_08(fd_cpu* cpu, reg8* tgt, uint8_t val) {
  fd_flags f = fd_get_flags(&cpu->reg);
  f.N = false;
  f.H = will_overflow(tgt->_, val);
  tgt->_ += val;
  f.Z = tgt->_ == 0;
  fd_set_flags(&cpu->reg, f);
  return INSTR(1, 4);
}

instr op_sub_rr_08(fd_cpu* cpu, reg8* tgt, uint8_t val) {
  fd_flags f = fd_get_flags(&cpu->reg);
  f.N = true;
  f.H = will_underflow(tgt->_, val);
  tgt->_ -= val;
  f.Z = tgt->_ == 0;
  fd_set_flags(&cpu->reg, f);
  return INSTR(1, 4);
}

instr op_inc_rr___(fd_cpu* cpu, reg8* tgt) {
  return op_add_rr_08(cpu, tgt, 1);
}

instr op_dec_rr___(fd_cpu* cpu, reg8* tgt) {
  return op_sub_rr_08(cpu, tgt, 1);
}

instr run(fd_cpu* cpu, uint8_t op[]) {
  // clang-format off
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
    case 0x09: return INSTR(0, 0);
    case 0x0A: return INSTR(0, 0);
    case 0x0B: return INSTR(0, 0);
    case 0x0C: return INSTR(0, 0);
    case 0x0D: return INSTR(0, 0);
    case 0x0E: return INSTR(0, 0);
    case 0x0F: return INSTR(0, 0);
  }
  // clang-format on

  assert(false);  // Op not implemented
  return INSTR(0, 0);
}

void tick(fd_cpu* cpu) {
  instr c = run(cpu, fdm_ptr(&cpu->mem, cpu->reg.PC._));
  assert(c.length > 0);
  assert(c.duration > 0);
  cpu->reg.PC._ += c.length;
}
