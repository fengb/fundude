#include "cpu.h"
#include <assert.h>
#include "fundude.h"

typedef struct {
  int length;
  int duration;
} instr;

#define INSTR(length, duration) ((instr){length, duration})

uint16_t w2(uint8_t op[]) {
  return (op[1] << 8) + op[2];
}

bool is_uint8_zero(int val) {
  return (val & 0xFF) == 0;
}

bool will_carry_from(int bit, int a, int b) {
  int mask = (1 << (bit + 1)) - 1;
  return (a & mask) + (b & mask) > mask;
}

bool will_borrow_from(int bit, int a, int b) {
  int mask = (1 << bit) - 1;
  return (a & mask) < (b & mask);
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

instr op_sys(fundude* fd, sys_mode mode, int length) {
  return INSTR(length, 4);
}

instr op_scf(fundude* fd) {
  fd->reg.FLAGS = (fd_flags){
      .Z = fd->reg.FLAGS.Z,
      .N = false,
      .H = false,
      .C = true,
  };
  return INSTR(1, 4);
}

instr op_jmp_08___(fundude* fd, uint8_t val) {
  return INSTR(val, 8);
}

instr op_jmp_if_08(fundude* fd, bool check, uint8_t val) {
  return INSTR(check ? val : 2, 8);
}

instr op_rlc_rr___(fundude* fd, reg8* tgt) {
  int msb = tgt->_ >> 7 & 1;

  tgt->_ = tgt->_ << 1 | msb;
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_),
      .N = false,
      .H = false,
      .C = msb,
  };
  return INSTR(1, 4);
}

instr op_rla_rr___(fundude* fd, reg8* tgt) {
  int msb = tgt->_ >> 7 & 1;

  tgt->_ = tgt->_ << 1 | fd->reg.FLAGS.C;
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_),
      .N = false,
      .H = false,
      .C = msb,
  };
  return INSTR(1, 4);
}

instr op_rrc_rr___(fundude* fd, reg8* tgt) {
  int lsb = tgt->_ & 1;

  tgt->_ = tgt->_ >> 1 | (lsb << 7);
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_),
      .N = false,
      .H = false,
      .C = lsb,
  };
  return INSTR(1, 4);
}

instr op_rra_rr___(fundude* fd, reg8* tgt) {
  int lsb = tgt->_ & 1;

  tgt->_ = tgt->_ >> 1 | (fd->reg.FLAGS.C << 7);
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_),
      .N = false,
      .H = false,
      .C = lsb,
  };
  return INSTR(1, 4);
}

instr op_lod_rr_08(fundude* _, reg8* tgt, uint8_t d8) {
  tgt->_ = d8;
  return INSTR(2, 8);
}

instr op_lod_rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  tgt->_ = fdm_get(&fd->mem, src->_);
  return INSTR(1, 8);
}

instr op_lod_ww_16(fundude* _, reg16* tgt, uint16_t d16) {
  tgt->_ = d16;
  return INSTR(3, 12);
}

instr op_lod_WW_rr(fundude* fd, reg16* tgt, reg8* src) {
  fdm_set(&fd->mem, tgt->_, src->_);
  return INSTR(1, 8);
}

instr op_lod_1F_ww(fundude* fd, uint16_t a16, reg16* src) {
  fdm_set(&fd->mem, a16, src->_);
  return INSTR(3, 20);
}

instr op_ldi_WW_rr(fundude* fd, reg16* tgt, reg8* src) {
  fdm_set(&fd->mem, tgt->_++, src->_);
  return INSTR(1, 8);
}

instr op_inc_ww___(fundude* _, reg16* tgt) {
  tgt->_++;
  return INSTR(1, 8);
}

instr op_dec_ww___(fundude* _, reg16* tgt) {
  tgt->_--;
  return INSTR(1, 8);
}

instr op_add_rr_08(fundude* fd, reg8* tgt, uint8_t val) {
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_ + val),
      .N = false,
      .H = will_carry_from(3, tgt->_, val),
      .C = will_carry_from(7, tgt->_, val),
  };
  tgt->_ += val;
  return INSTR(1, 4);
}

instr op_add_ww_ww(fundude* fd, reg16* tgt, reg16* src) {
  fd->reg.FLAGS = (fd_flags){
      .Z = fd->reg.FLAGS.Z,
      .N = false,
      .H = will_carry_from(11, tgt->_, src->_),
      .C = will_carry_from(15, tgt->_, src->_),
  };
  tgt->_ += src->_;
  return INSTR(1, 8);
}

instr op_sub_rr_08(fundude* fd, reg8* tgt, uint8_t val) {
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_ - val),
      .N = true,
      .H = !will_borrow_from(4, tgt->_, val),
      .C = !will_borrow_from(8, tgt->_, val),
  };
  tgt->_ -= val;
  return INSTR(1, 4);
}

instr op_inc_rr___(fundude* fd, reg8* tgt) {
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_ + 1),
      .N = false,
      .H = will_carry_from(3, tgt->_, 1),
      .C = fd->reg.FLAGS.C,
  };
  tgt->_++;
  return INSTR(1, 4);
}

instr op_dec_rr___(fundude* fd, reg8* tgt) {
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_ - 1),
      .N = true,
      .H = will_carry_from(3, tgt->_, 1),
      .C = fd->reg.FLAGS.C,
  };
  tgt->_--;
  return INSTR(1, 4);
}

instr run(fundude* fd, uint8_t op[]) {
  switch (op[0]) {
    case 0x00: return op_nop();
    case 0x01: return op_lod_ww_16(fd, &fd->reg.BC, w2(op));
    case 0x02: return op_lod_WW_rr(fd, &fd->reg.BC, &fd->reg.A);
    case 0x03: return op_inc_ww___(fd, &fd->reg.BC);
    case 0x04: return op_inc_rr___(fd, &fd->reg.B);
    case 0x05: return op_dec_rr___(fd, &fd->reg.B);
    case 0x06: return op_lod_rr_08(fd, &fd->reg.B, op[1]);
    case 0x07: return op_rlc_rr___(fd, &fd->reg.A);
    case 0x08: return op_lod_1F_ww(fd, w2(op), &fd->reg.SP);
    case 0x09: return op_add_ww_ww(fd, &fd->reg.HL, &fd->reg.BC);
    case 0x0A: return op_lod_rr_WW(fd, &fd->reg.A, &fd->reg.BC);
    case 0x0B: return op_dec_ww___(fd, &fd->reg.BC);
    case 0x0C: return op_inc_rr___(fd, &fd->reg.C);
    case 0x0D: return op_dec_rr___(fd, &fd->reg.C);
    case 0x0E: return op_lod_rr_08(fd, &fd->reg.C, op[1]);
    case 0x0F: return op_rrc_rr___(fd, &fd->reg.A);

    case 0x10: return op_sys(fd, SYS_STOP, 2);
    case 0x11: return op_lod_ww_16(fd, &fd->reg.DE, w2(op));
    case 0x12: return op_lod_WW_rr(fd, &fd->reg.DE, &fd->reg.A);
    case 0x13: return op_inc_ww___(fd, &fd->reg.DE);
    case 0x14: return op_inc_rr___(fd, &fd->reg.D);
    case 0x15: return op_dec_rr___(fd, &fd->reg.D);
    case 0x16: return op_lod_rr_08(fd, &fd->reg.D, op[1]);
    case 0x17: return op_rla_rr___(fd, &fd->reg.A);
    case 0x18: return op_jmp_08___(fd, op[1]);
    case 0x19: return op_add_ww_ww(fd, &fd->reg.HL, &fd->reg.DE);
    case 0x1A: return op_lod_rr_WW(fd, &fd->reg.A, &fd->reg.DE);
    case 0x1B: return op_dec_ww___(fd, &fd->reg.DE);
    case 0x1C: return op_inc_rr___(fd, &fd->reg.E);
    case 0x1D: return op_dec_rr___(fd, &fd->reg.E);
    case 0x1E: return op_lod_rr_08(fd, &fd->reg.E, op[1]);
    case 0x1F: return op_rra_rr___(fd, &fd->reg.A);

    case 0x20: return op_jmp_if_08(fd, !fd->reg.FLAGS.Z, op[1]);
    case 0x21: return op_lod_ww_16(fd, &fd->reg.HL, w2(op));
    case 0x22: return op_ldi_WW_rr(fd, &fd->reg.HL, &fd->reg.A);
    case 0x23: return op_inc_ww___(fd, &fd->reg.HL);
    case 0x24: return op_inc_rr___(fd, &fd->reg.H);
    case 0x25: return op_dec_rr___(fd, &fd->reg.H);
    case 0x26: return op_lod_rr_08(fd, &fd->reg.H, op[1]);
    case 0x27: return op_scf(fd);
    case 0x28: return op_jmp_if_08(fd, fd->reg.FLAGS.Z, op[1]);
  }

  assert(false);  // Op not implemented
  return INSTR(0, 0);
}

void tick(fundude* fd) {
  instr c = run(fd, fdm_ptr(&fd->mem, fd->reg.PC._));
  assert(c.length > 0);
  assert(c.duration > 0);
  fd->reg.PC._ += c.length;
}
