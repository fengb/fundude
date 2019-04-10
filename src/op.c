#include "op.h"
#include <assert.h>
#include "debug.h"
#include "fundude.h"
#include "op_cb.h"
#include "op_do.h"

static uint8_t with8(uint8_t op[]) {
  return op[1];
}

static uint16_t with16(uint8_t op[]) {
  return (op[2] << 8) + op[1];
}

static bool cond_check(fundude* fd, cond c) {
  switch (c) {
    case COND_NZ: return !fd->reg.FLAGS.Z;
    case COND_Z: return fd->reg.FLAGS.Z;
    case COND_NC: return !fd->reg.FLAGS.C;
    case COND_C: return fd->reg.FLAGS.C;
  }
}

int signed_offset(uint8_t val) {
  return (val < 128) ? val : (int)val - 256;
}

/* op_ functions are a lot more scannable if the names line up, hence the
   cryptic abbreviations:

     rr -- register (8bit)
     ww -- wide register (16bit)
     d8 -- byte literal (8bit)
     df -- double-byte literal (16bit)

     RR -- register address (8bit + $FF00)
     WW -- wide register address (16bit)
     A8 -- byte address (8bit + $FF00)
     AF -- double-byte address (16bit)
     R8 -- byte address offset (8bit-signed + $FF00)
*/

op_result op_nop(fundude* fd) {
  return OP_STEP(fd, 1, 4, "NOP");
}

op_result op_sys(fundude* fd, sys_mode mode, int length) {
  return OP_STEP(fd, length, 4, db_sys_mode(mode));
}

op_result op_scf(fundude* fd) {
  fd->reg.FLAGS = (fd_flags){
      .Z = fd->reg.FLAGS.Z,
      .N = false,
      .H = false,
      .C = true,
  };
  return OP_STEP(fd, 1, 4, "SCF");
}

op_result op_ccf(fundude* fd) {
  fd->reg.FLAGS = (fd_flags){
      .Z = fd->reg.FLAGS.Z,
      .N = false,
      .H = false,
      .C = !fd->reg.FLAGS.C,
  };
  return OP_STEP(fd, 1, 4, "CCF");
}

op_result op_int______(fundude* fd, bool set) {
  // TODO: enable/disable interrupt
  return OP_STEP(fd, 1, 4, set ? "EI" : "DI");
}

op_result op_daa_rr___(fundude* fd, reg8* dst) {
  uint8_t lb = dst->_ & 0xF;
  uint8_t hb = (dst->_ >> 4) & 0xF;
  bool carry = fd->reg.FLAGS.C;

  if (fd->reg.FLAGS.N) {
    if (lb >= 10) {
      lb -= 6;
    }
    if (hb >= 10) {
      hb -= 10;
      carry = true;
    }
  } else {
    if (lb >= 10) {
      lb -= 10;
      hb++;
    }
    if (hb >= 10) {
      hb -= 10;
      carry = true;
    }
  }

  dst->_ = (hb << 4) | lb;
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(dst->_),
      .N = fd->reg.FLAGS.N,
      .H = false,
      .C = carry,
  };
  return OP_STEP(fd, 1, 4, "DAA %s", db_reg8(fd, dst));
}

op_result op_jr__R8___(fundude* fd, uint8_t val) {
  int offset = signed_offset(val);
  return OP_JUMP(fd->reg.PC._ + offset, 2, 8, "JR $%02X", val);
}

op_result op_jr__if_R8(fundude* fd, cond c, uint8_t val) {
  uint16_t length = 3;
  if (!cond_check(fd, c)) {
    val = length;
  }
  int offset = signed_offset(val);
  return OP_JUMP(fd->reg.PC._ + offset, 2, 8, "JR %s $%02X", db_cond(c), val);
}

op_result op_jp__AF___(fundude* fd, uint16_t target) {
  return OP_JUMP(target, 3, 12, "JP $%04X", target);
}

op_result op_jp__if_AF(fundude* fd, cond c, uint16_t target) {
  uint16_t length = 3;
  if (!cond_check(fd, c)) {
    target = fd->reg.PC._ + 3;
  }
  return OP_JUMP(target, 3, 12, "JP %s $%02X", db_cond(c), target);
}

op_result op_jp__WW___(fundude* fd, reg16* tgt) {
  uint16_t target = fdm_get(&fd->mem, tgt->_);
  return OP_JUMP(target, 1, 4, "JP (%s)", db_reg16(fd, tgt));
}

op_result op_ret______(fundude* fd) {
  uint8_t val = do_pop(fd);
  return OP_JUMP(val, 1, 8, "RET");
}

op_result op_rti______(fundude* fd) {
  uint8_t val = do_pop(fd);
  // TODO: enable interrupts
  return OP_JUMP(val, 1, 8, "RETI");
}

op_result op_ret_if___(fundude* fd, cond c) {
  if (!cond_check(fd, c)) {
    return OP_STEP(fd, 1, 8, "RET %s", db_cond(c));
  }
  uint8_t val = do_pop(fd);
  return OP_JUMP(val, 1, 8, "RET %s", db_cond(c));
}

op_result op_rst_d8___(fundude* fd, uint8_t val) {
  do_push(fd, fd->reg.PC._);
  return OP_JUMP(val, 1, 32, "RST %02XH", val);
}

op_result op_rlc_rr___(fundude* fd, reg8* tgt) {
  do_rlc(fd, &tgt->_);
  return OP_STEP(fd, 1, 4, "RLCA %s", db_reg8(fd, tgt));
}

op_result op_rla_rr___(fundude* fd, reg8* tgt) {
  do_rl(fd, &tgt->_);
  return OP_STEP(fd, 1, 4, "RLA %s", db_reg8(fd, tgt));
}

op_result op_rrc_rr___(fundude* fd, reg8* tgt) {
  do_rrc(fd, &tgt->_);
  return OP_STEP(fd, 1, 4, "RRC %s", db_reg8(fd, tgt));
}

op_result op_rra_rr___(fundude* fd, reg8* tgt) {
  do_rr(fd, &tgt->_);
  return OP_STEP(fd, 1, 4, "RRA %s", db_reg8(fd, tgt));
}

op_result op_ld__rr_d8(fundude* fd, reg8* tgt, uint8_t d8) {
  tgt->_ = d8;
  return OP_STEP(fd, 2, 8, "LD %s,$%02X", db_reg8(fd, tgt), d8);
}

op_result op_ld__rr_rr(fundude* fd, reg8* tgt, reg8* src) {
  tgt->_ = src->_;
  return OP_STEP(fd, 1, 4, "LD %s,%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_ld__rr_RR(fundude* fd, reg8* tgt, reg8* src) {
  tgt->_ = fdm_get(&fd->mem, 0xFF00 + src->_);
  return OP_STEP(fd, 1, 8, "LD %s,(%s)", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_ld__RR_rr(fundude* fd, reg8* tgt, reg8* src) {
  fdm_set(&fd->mem, 0xFF00 + tgt->_, src->_);
  return OP_STEP(fd, 1, 8, "LD (%s),%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_ld__rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  tgt->_ = fdm_get(&fd->mem, src->_);
  return OP_STEP(fd, 1, 8, "LD %s,(%s)", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_ld__ww_df(fundude* fd, reg16* tgt, uint16_t ddf) {
  tgt->_ = ddf;
  return OP_STEP(fd, 3, 12, "LD %s,$%04X", db_reg16(fd, tgt), ddf);
}

op_result op_ld__WW_rr(fundude* fd, reg16* tgt, reg8* src) {
  fdm_set(&fd->mem, tgt->_, src->_);
  return OP_STEP(fd, 1, 8, "LD (%s),%s", db_reg16(fd, tgt), db_reg8(fd, src));
}

op_result op_ld__AF_ww(fundude* fd, uint16_t a16, reg16* src) {
  fdm_set(&fd->mem, a16, src->_);
  return OP_STEP(fd, 3, 20, "LD ($%04X),%s", a16, db_reg16(fd, src));
}

op_result op_ld__WW_d8(fundude* fd, reg16* tgt, uint8_t val) {
  fdm_set(&fd->mem, tgt->_, val);
  return OP_STEP(fd, 2, 12, "LD (%s),$%02X", db_reg16(fd, tgt), val);
}

op_result op_ld__AF_rr(fundude* fd, uint16_t tgt, reg8* src) {
  fdm_set(&fd->mem, tgt, src->_);
  return OP_STEP(fd, 3, 16, "LD ($%04X),%s", tgt, db_reg8(fd, src));
}

op_result op_ld__rr_AF(fundude* fd, reg8* tgt, uint16_t val) {
  tgt->_ = fdm_get(&fd->mem, val);
  return OP_STEP(fd, 3, 16, "LD %s,($%04X)", db_reg8(fd, tgt), val);
}

op_result op_ld__ww_ww(fundude* fd, reg16* tgt, reg16* src) {
  tgt->_ = src->_;
  return OP_STEP(fd, 3, 16, "LD %s,%s", db_reg16(fd, tgt), db_reg16(fd, src));
}

op_result op_ld__ww_ww_R8(fundude* fd, reg16* tgt, reg16* src, uint8_t val) {
  int offset = signed_offset(val);
  tgt->_ = src->_ + offset;
  return OP_STEP(fd, 3, 16, "LD %s,%s+$%02X", db_reg16(fd, tgt),
                 db_reg16(fd, src), val);
}

op_result op_ldi_WW_rr(fundude* fd, reg16* tgt, reg8* src) {
  fdm_set(&fd->mem, tgt->_++, src->_);
  return OP_STEP(fd, 1, 8, "LD (%s+),%s", db_reg16(fd, tgt), db_reg8(fd, src));
}

op_result op_ldi_rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  fdm_set(&fd->mem, tgt->_, src->_++);
  return OP_STEP(fd, 1, 8, "LD %s,(%s+)", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_ldd_WW_rr(fundude* fd, reg16* tgt, reg8* src) {
  fdm_set(&fd->mem, tgt->_--, src->_);
  return OP_STEP(fd, 1, 8, "LD (%s-),%s", db_reg16(fd, tgt), db_reg8(fd, src));
}

op_result op_ldd_rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  fdm_set(&fd->mem, tgt->_, src->_--);
  return OP_STEP(fd, 1, 8, "LD %s,(%s-)", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_ldh_A8_rr(fundude* fd, uint8_t tgt, reg8* src) {
  fdm_set(&fd->mem, 0xFF00 + tgt, src->_);
  return OP_STEP(fd, 2, 12, "LDH ($FF00+%02X),%s", tgt, db_reg8(fd, src));
}

op_result op_ldh_rr_A8(fundude* fd, reg8* tgt, uint8_t src) {
  tgt->_ = fdm_get(&fd->mem, 0xFF00 + src);
  return OP_STEP(fd, 2, 12, "LDH %s,($FF00+%02X)", db_reg8(fd, tgt), src);
}

op_result op_inc_ww___(fundude* fd, reg16* tgt) {
  tgt->_++;
  return OP_STEP(fd, 1, 8, "INC %s", db_reg16(fd, tgt));
}

op_result op_inc_WW___(fundude* fd, reg16* tgt) {
  uint8_t val = fdm_get(&fd->mem, tgt->_);

  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(val + 1),
      .N = false,
      .H = will_carry_from(3, val, 1),
      .C = fd->reg.FLAGS.C,
  };
  fdm_set(&fd->mem, tgt->_, val + 1);
  return OP_STEP(fd, 1, 12, "INC (%s)", db_reg16(fd, tgt));
}

op_result op_dec_ww___(fundude* fd, reg16* tgt) {
  tgt->_--;
  return OP_STEP(fd, 1, 8, "DEC %s", db_reg16(fd, tgt));
}

op_result op_dec_WW___(fundude* fd, reg16* tgt) {
  uint8_t val = fdm_get(&fd->mem, tgt->_);

  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(val - 1),
      .N = true,
      .H = will_borrow_from(4, val, 1),
      .C = fd->reg.FLAGS.C,
  };
  fdm_set(&fd->mem, tgt->_, val - 1);
  return OP_STEP(fd, 1, 12, "DEC (%s)", db_reg16(fd, tgt));
}

op_result op_add_rr_rr(fundude* fd, reg8* tgt, reg8* src) {
  do_add_rr(fd, tgt, src->_);
  return OP_STEP(fd, 1, 4, "ADD %s,%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_add_rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  do_add_rr(fd, tgt, fdm_get(&fd->mem, src->_));
  return OP_STEP(fd, 1, 8, "ADD %s,%s", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_add_rr_d8(fundude* fd, reg8* tgt, uint8_t val) {
  do_add_rr(fd, tgt, val);
  return OP_STEP(fd, 2, 8, "ADD %s,$%02X", db_reg8(fd, tgt), val);
}

op_result op_add_ww_ww(fundude* fd, reg16* tgt, reg16* src) {
  fd->reg.FLAGS = (fd_flags){
      .Z = fd->reg.FLAGS.Z,
      .N = false,
      .H = will_carry_from(11, tgt->_, src->_),
      .C = will_carry_from(15, tgt->_, src->_),
  };
  tgt->_ += src->_;
  return OP_STEP(fd, 1, 8, "ADD %s,%s", db_reg16(fd, tgt), db_reg16(fd, src));
}

op_result op_add_ww_R8(fundude* fd, reg16* tgt, uint8_t val) {
  int offset = signed_offset(val);
  fd->reg.FLAGS = (fd_flags){
      .Z = false,
      .N = false,
      .H = will_carry_from(11, tgt->_, offset),
      .C = will_carry_from(15, tgt->_, offset),
  };
  tgt->_ += offset;
  return OP_STEP(fd, 2, 16, "ADD %s,$%02X", db_reg16(fd, tgt), val);
}

op_result op_adc_rr_rr(fundude* fd, reg8* tgt, reg8* src) {
  do_add_rr(fd, tgt, fd->reg.FLAGS.C + src->_);
  return OP_STEP(fd, 1, 4, "ADC %s,%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_adc_rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  do_add_rr(fd, tgt, fd->reg.FLAGS.C + fdm_get(&fd->mem, src->_));
  return OP_STEP(fd, 1, 8, "ADC %s,%s", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_adc_rr_d8(fundude* fd, reg8* tgt, uint8_t val) {
  do_add_rr(fd, tgt, fd->reg.FLAGS.C + val);
  return OP_STEP(fd, 1, 4, "ADC %s,$%02X", db_reg8(fd, tgt), val);
}

op_result op_sub_rr_rr(fundude* fd, reg8* tgt, reg8* src) {
  do_sub_rr(fd, tgt, src->_);
  return OP_STEP(fd, 1, 4, "SUB %s,%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_sub_rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  do_sub_rr(fd, tgt, fdm_get(&fd->mem, src->_));
  return OP_STEP(fd, 1, 8, "SUB %s,%s", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_sub_rr_d8(fundude* fd, reg8* tgt, uint8_t val) {
  do_sub_rr(fd, tgt, val);
  return OP_STEP(fd, 2, 8, "SUB %s,$%02X", db_reg8(fd, tgt), val);
}

op_result op_sbc_rr_rr(fundude* fd, reg8* tgt, reg8* src) {
  do_sub_rr(fd, tgt, fd->reg.FLAGS.C + src->_);
  return OP_STEP(fd, 1, 4, "SBC %s,%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_sbc_rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  do_sub_rr(fd, tgt, fd->reg.FLAGS.C + fdm_get(&fd->mem, src->_));
  return OP_STEP(fd, 1, 8, "SBC %s,%s", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_sbc_rr_d8(fundude* fd, reg8* tgt, uint8_t val) {
  do_sub_rr(fd, tgt, fd->reg.FLAGS.C + val);
  return OP_STEP(fd, 1, 8, "SBC %s,$%02X", db_reg8(fd, tgt), val);
}

op_result op_and_rr_rr(fundude* fd, reg8* tgt, reg8* src) {
  do_and_rr(fd, tgt, src->_);
  return OP_STEP(fd, 1, 4, "AND %s,%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_and_rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  do_and_rr(fd, tgt, fdm_get(&fd->mem, src->_));
  return OP_STEP(fd, 1, 8, "AND %s,%s", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_and_rr_d8(fundude* fd, reg8* tgt, uint8_t val) {
  do_and_rr(fd, tgt, val);
  return OP_STEP(fd, 2, 8, "AND %s,$%02X", db_reg8(fd, tgt), val);
}

op_result op_or__rr_rr(fundude* fd, reg8* tgt, reg8* src) {
  do_or__rr(fd, tgt, src->_);
  return OP_STEP(fd, 1, 4, "OR %s,%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_or__rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  do_or__rr(fd, tgt, fdm_get(&fd->mem, src->_));
  return OP_STEP(fd, 1, 8, "OR %s,%s", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_or__rr_d8(fundude* fd, reg8* tgt, uint8_t val) {
  do_or__rr(fd, tgt, val);
  return OP_STEP(fd, 2, 8, "OR %s,$%02X", db_reg8(fd, tgt), val);
}

op_result op_xor_rr_rr(fundude* fd, reg8* tgt, reg8* src) {
  do_xor_rr(fd, tgt, src->_);
  return OP_STEP(fd, 1, 4, "XOR %s,%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_xor_rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  do_xor_rr(fd, tgt, fdm_get(&fd->mem, src->_));
  return OP_STEP(fd, 1, 8, "XOR %s,%s", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_xor_rr_d8(fundude* fd, reg8* tgt, uint8_t val) {
  do_xor_rr(fd, tgt, val);
  return OP_STEP(fd, 2, 8, "XOR %s,$%02X", db_reg8(fd, tgt), val);
}

op_result op_cp__rr_rr(fundude* fd, reg8* tgt, reg8* src) {
  do_cp__rr(fd, tgt, src->_);
  return OP_STEP(fd, 1, 4, "CP %s,%s", db_reg8(fd, tgt), db_reg8(fd, src));
}

op_result op_cp__rr_WW(fundude* fd, reg8* tgt, reg16* src) {
  do_cp__rr(fd, tgt, fdm_get(&fd->mem, src->_));
  return OP_STEP(fd, 1, 8, "CP %s,%s", db_reg8(fd, tgt), db_reg16(fd, src));
}

op_result op_cp__rr_d8(fundude* fd, reg8* tgt, uint8_t val) {
  do_cp__rr(fd, tgt, val);
  return OP_STEP(fd, 2, 8, "CP %s,$%02X", db_reg8(fd, tgt), val);
}

op_result op_inc_rr___(fundude* fd, reg8* tgt) {
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_ + 1),
      .N = false,
      .H = will_carry_from(3, tgt->_, 1),
      .C = fd->reg.FLAGS.C,
  };
  tgt->_++;
  return OP_STEP(fd, 1, 4, "INC %s", db_reg8(fd, tgt));
}

op_result op_dec_rr___(fundude* fd, reg8* tgt) {
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(tgt->_ - 1),
      .N = true,
      .H = will_carry_from(3, tgt->_, 1),
      .C = fd->reg.FLAGS.C,
  };
  tgt->_--;
  return OP_STEP(fd, 1, 4, "DEC %s", db_reg8(fd, tgt));
}

op_result op_cpl_rr___(fundude* fd, reg8* tgt) {
  fd->reg.FLAGS = (fd_flags){
      .Z = fd->reg.FLAGS.Z,
      .N = true,
      .H = true,
      .C = fd->reg.FLAGS.C,
  };
  return OP_STEP(fd, 1, 4, "CPL %s", db_reg8(fd, tgt));
}

op_result op_pop_ww___(fundude* fd, reg16* tgt) {
  // This logic would be easier of we passed in 2x reg8,
  // but it would be semantically incorrect. Sad panda.
  uint8_t hb = do_pop(fd);
  uint8_t lb = do_pop(fd);
  tgt->_ = (hb << 8) & lb;
  return OP_STEP(fd, 1, 12, "POP %s", db_reg16(fd, tgt));
}

op_result op_psh_ww___(fundude* fd, reg16* tgt) {
  uint8_t hb = tgt->_ >> 8;
  uint8_t lb = tgt->_ & 0xFF;
  do_push(fd, lb);
  do_push(fd, hb);
  return OP_STEP(fd, 1, 16, "PUSH %s", db_reg16(fd, tgt));
}

op_result op_cal_AF___(fundude* fd, uint16_t val) {
  do_push(fd, fd->reg.PC._ + 3);
  return OP_JUMP(val, 3, 12, "CALL $%04X", val);
}

op_result op_cal_if_AF(fundude* fd, cond c, uint16_t val) {
  if (!cond_check(fd, c)) {
    return OP_STEP(fd, 3, 12, "CALL %s,$%04X", db_cond(c), val);
  }
  do_push(fd, fd->reg.PC._ + 3);
  return OP_JUMP(val, 3, 12, "CALL %s,$%04X", db_cond(c), val);
}

static op_result OP_ILLEGAL = {0, 1, 4, "ILLEGAL"};

op_result op_tick(fundude* fd, uint8_t op[]) {
  switch (op[0]) {
    case 0x00: return op_nop(fd);
    case 0x01: return op_ld__ww_df(fd, &fd->reg.BC, with16(op));
    case 0x02: return op_ld__WW_rr(fd, &fd->reg.BC, &fd->reg.A);
    case 0x03: return op_inc_ww___(fd, &fd->reg.BC);
    case 0x04: return op_inc_rr___(fd, &fd->reg.B);
    case 0x05: return op_dec_rr___(fd, &fd->reg.B);
    case 0x06: return op_ld__rr_d8(fd, &fd->reg.B, with8(op));
    case 0x07: return op_rlc_rr___(fd, &fd->reg.A);
    case 0x08: return op_ld__AF_ww(fd, with16(op), &fd->reg.SP);
    case 0x09: return op_add_ww_ww(fd, &fd->reg.HL, &fd->reg.BC);
    case 0x0A: return op_ld__rr_WW(fd, &fd->reg.A, &fd->reg.BC);
    case 0x0B: return op_dec_ww___(fd, &fd->reg.BC);
    case 0x0C: return op_inc_rr___(fd, &fd->reg.C);
    case 0x0D: return op_dec_rr___(fd, &fd->reg.C);
    case 0x0E: return op_ld__rr_d8(fd, &fd->reg.C, with8(op));
    case 0x0F: return op_rrc_rr___(fd, &fd->reg.A);

    case 0x10: return op_sys(fd, SYS_STOP, 2);
    case 0x11: return op_ld__ww_df(fd, &fd->reg.DE, with16(op));
    case 0x12: return op_ld__WW_rr(fd, &fd->reg.DE, &fd->reg.A);
    case 0x13: return op_inc_ww___(fd, &fd->reg.DE);
    case 0x14: return op_inc_rr___(fd, &fd->reg.D);
    case 0x15: return op_dec_rr___(fd, &fd->reg.D);
    case 0x16: return op_ld__rr_d8(fd, &fd->reg.D, with8(op));
    case 0x17: return op_rla_rr___(fd, &fd->reg.A);
    case 0x18: return op_jr__R8___(fd, with8(op));
    case 0x19: return op_add_ww_ww(fd, &fd->reg.HL, &fd->reg.DE);
    case 0x1A: return op_ld__rr_WW(fd, &fd->reg.A, &fd->reg.DE);
    case 0x1B: return op_dec_ww___(fd, &fd->reg.DE);
    case 0x1C: return op_inc_rr___(fd, &fd->reg.E);
    case 0x1D: return op_dec_rr___(fd, &fd->reg.E);
    case 0x1E: return op_ld__rr_d8(fd, &fd->reg.E, with8(op));
    case 0x1F: return op_rra_rr___(fd, &fd->reg.A);

    case 0x20: return op_jr__if_R8(fd, COND_NZ, with8(op));
    case 0x21: return op_ld__ww_df(fd, &fd->reg.HL, with16(op));
    case 0x22: return op_ldi_WW_rr(fd, &fd->reg.HL, &fd->reg.A);
    case 0x23: return op_inc_ww___(fd, &fd->reg.HL);
    case 0x24: return op_inc_rr___(fd, &fd->reg.H);
    case 0x25: return op_dec_rr___(fd, &fd->reg.H);
    case 0x26: return op_ld__rr_d8(fd, &fd->reg.H, with8(op));
    case 0x27: return op_daa_rr___(fd, &fd->reg.A);
    case 0x28: return op_jr__if_R8(fd, COND_Z, with8(op));
    case 0x29: return op_add_ww_ww(fd, &fd->reg.HL, &fd->reg.HL);
    case 0x2A: return op_ldi_rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0x2B: return op_dec_ww___(fd, &fd->reg.HL);
    case 0x2C: return op_inc_rr___(fd, &fd->reg.L);
    case 0x2D: return op_dec_rr___(fd, &fd->reg.L);
    case 0x2E: return op_ld__rr_d8(fd, &fd->reg.L, with8(op));
    case 0x2F: return op_cpl_rr___(fd, &fd->reg.A);

    case 0x30: return op_jr__if_R8(fd, COND_NC, with8(op));
    case 0x31: return op_ld__ww_df(fd, &fd->reg.SP, with16(op));
    case 0x32: return op_ldd_WW_rr(fd, &fd->reg.HL, &fd->reg.A);
    case 0x33: return op_inc_ww___(fd, &fd->reg.SP);
    case 0x34: return op_inc_WW___(fd, &fd->reg.HL);
    case 0x35: return op_dec_WW___(fd, &fd->reg.HL);
    case 0x36: return op_ld__WW_d8(fd, &fd->reg.HL, with8(op));
    case 0x37: return op_scf(fd);
    case 0x38: return op_jr__if_R8(fd, COND_C, with8(op));
    case 0x39: return op_add_ww_ww(fd, &fd->reg.HL, &fd->reg.SP);
    case 0x3A: return op_ldd_rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0x3B: return op_dec_ww___(fd, &fd->reg.SP);
    case 0x3C: return op_inc_rr___(fd, &fd->reg.A);
    case 0x3D: return op_dec_rr___(fd, &fd->reg.A);
    case 0x3E: return op_ld__rr_d8(fd, &fd->reg.A, with8(op));
    case 0x3F: return op_ccf(fd);

    case 0x40: return op_ld__rr_rr(fd, &fd->reg.B, &fd->reg.B);
    case 0x41: return op_ld__rr_rr(fd, &fd->reg.B, &fd->reg.C);
    case 0x42: return op_ld__rr_rr(fd, &fd->reg.B, &fd->reg.D);
    case 0x43: return op_ld__rr_rr(fd, &fd->reg.B, &fd->reg.E);
    case 0x44: return op_ld__rr_rr(fd, &fd->reg.B, &fd->reg.H);
    case 0x45: return op_ld__rr_rr(fd, &fd->reg.B, &fd->reg.L);
    case 0x46: return op_ld__rr_WW(fd, &fd->reg.B, &fd->reg.HL);
    case 0x47: return op_ld__rr_rr(fd, &fd->reg.B, &fd->reg.A);
    case 0x48: return op_ld__rr_rr(fd, &fd->reg.C, &fd->reg.B);
    case 0x49: return op_ld__rr_rr(fd, &fd->reg.C, &fd->reg.C);
    case 0x4A: return op_ld__rr_rr(fd, &fd->reg.C, &fd->reg.D);
    case 0x4B: return op_ld__rr_rr(fd, &fd->reg.C, &fd->reg.E);
    case 0x4C: return op_ld__rr_rr(fd, &fd->reg.C, &fd->reg.H);
    case 0x4D: return op_ld__rr_rr(fd, &fd->reg.C, &fd->reg.L);
    case 0x4E: return op_ld__rr_WW(fd, &fd->reg.C, &fd->reg.HL);
    case 0x4F: return op_ld__rr_rr(fd, &fd->reg.C, &fd->reg.A);

    case 0x50: return op_ld__rr_rr(fd, &fd->reg.D, &fd->reg.B);
    case 0x51: return op_ld__rr_rr(fd, &fd->reg.D, &fd->reg.C);
    case 0x52: return op_ld__rr_rr(fd, &fd->reg.D, &fd->reg.D);
    case 0x53: return op_ld__rr_rr(fd, &fd->reg.D, &fd->reg.E);
    case 0x54: return op_ld__rr_rr(fd, &fd->reg.D, &fd->reg.H);
    case 0x55: return op_ld__rr_rr(fd, &fd->reg.D, &fd->reg.L);
    case 0x56: return op_ld__rr_WW(fd, &fd->reg.D, &fd->reg.HL);
    case 0x57: return op_ld__rr_rr(fd, &fd->reg.D, &fd->reg.A);
    case 0x58: return op_ld__rr_rr(fd, &fd->reg.E, &fd->reg.B);
    case 0x59: return op_ld__rr_rr(fd, &fd->reg.E, &fd->reg.C);
    case 0x5A: return op_ld__rr_rr(fd, &fd->reg.E, &fd->reg.D);
    case 0x5B: return op_ld__rr_rr(fd, &fd->reg.E, &fd->reg.E);
    case 0x5C: return op_ld__rr_rr(fd, &fd->reg.E, &fd->reg.H);
    case 0x5D: return op_ld__rr_rr(fd, &fd->reg.E, &fd->reg.L);
    case 0x5E: return op_ld__rr_WW(fd, &fd->reg.E, &fd->reg.HL);
    case 0x5F: return op_ld__rr_rr(fd, &fd->reg.E, &fd->reg.A);

    case 0x60: return op_ld__rr_rr(fd, &fd->reg.H, &fd->reg.B);
    case 0x61: return op_ld__rr_rr(fd, &fd->reg.H, &fd->reg.C);
    case 0x62: return op_ld__rr_rr(fd, &fd->reg.H, &fd->reg.D);
    case 0x63: return op_ld__rr_rr(fd, &fd->reg.H, &fd->reg.E);
    case 0x64: return op_ld__rr_rr(fd, &fd->reg.H, &fd->reg.H);
    case 0x65: return op_ld__rr_rr(fd, &fd->reg.H, &fd->reg.L);
    case 0x66: return op_ld__rr_WW(fd, &fd->reg.H, &fd->reg.HL);
    case 0x67: return op_ld__rr_rr(fd, &fd->reg.H, &fd->reg.A);
    case 0x68: return op_ld__rr_rr(fd, &fd->reg.L, &fd->reg.B);
    case 0x69: return op_ld__rr_rr(fd, &fd->reg.L, &fd->reg.C);
    case 0x6A: return op_ld__rr_rr(fd, &fd->reg.L, &fd->reg.D);
    case 0x6B: return op_ld__rr_rr(fd, &fd->reg.L, &fd->reg.E);
    case 0x6C: return op_ld__rr_rr(fd, &fd->reg.L, &fd->reg.H);
    case 0x6D: return op_ld__rr_rr(fd, &fd->reg.L, &fd->reg.L);
    case 0x6E: return op_ld__rr_WW(fd, &fd->reg.L, &fd->reg.HL);
    case 0x6F: return op_ld__rr_rr(fd, &fd->reg.L, &fd->reg.A);

    case 0x70: return op_ld__WW_rr(fd, &fd->reg.HL, &fd->reg.B);
    case 0x71: return op_ld__WW_rr(fd, &fd->reg.HL, &fd->reg.C);
    case 0x72: return op_ld__WW_rr(fd, &fd->reg.HL, &fd->reg.D);
    case 0x73: return op_ld__WW_rr(fd, &fd->reg.HL, &fd->reg.E);
    case 0x74: return op_ld__WW_rr(fd, &fd->reg.HL, &fd->reg.H);
    case 0x75: return op_ld__WW_rr(fd, &fd->reg.HL, &fd->reg.L);
    case 0x76: return op_sys(fd, SYS_HALT, 1);
    case 0x77: return op_ld__WW_rr(fd, &fd->reg.HL, &fd->reg.A);
    case 0x78: return op_ld__rr_rr(fd, &fd->reg.A, &fd->reg.B);
    case 0x79: return op_ld__rr_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0x7A: return op_ld__rr_rr(fd, &fd->reg.A, &fd->reg.D);
    case 0x7B: return op_ld__rr_rr(fd, &fd->reg.A, &fd->reg.E);
    case 0x7C: return op_ld__rr_rr(fd, &fd->reg.A, &fd->reg.H);
    case 0x7D: return op_ld__rr_rr(fd, &fd->reg.A, &fd->reg.L);
    case 0x7E: return op_ld__rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0x7F: return op_ld__rr_rr(fd, &fd->reg.A, &fd->reg.A);

    case 0x80: return op_add_rr_rr(fd, &fd->reg.A, &fd->reg.B);
    case 0x81: return op_add_rr_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0x82: return op_add_rr_rr(fd, &fd->reg.A, &fd->reg.D);
    case 0x83: return op_add_rr_rr(fd, &fd->reg.A, &fd->reg.E);
    case 0x84: return op_add_rr_rr(fd, &fd->reg.A, &fd->reg.H);
    case 0x85: return op_add_rr_rr(fd, &fd->reg.A, &fd->reg.L);
    case 0x86: return op_add_rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0x87: return op_add_rr_rr(fd, &fd->reg.A, &fd->reg.A);
    case 0x88: return op_adc_rr_rr(fd, &fd->reg.A, &fd->reg.B);
    case 0x89: return op_adc_rr_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0x8A: return op_adc_rr_rr(fd, &fd->reg.A, &fd->reg.D);
    case 0x8B: return op_adc_rr_rr(fd, &fd->reg.A, &fd->reg.E);
    case 0x8C: return op_adc_rr_rr(fd, &fd->reg.A, &fd->reg.H);
    case 0x8D: return op_adc_rr_rr(fd, &fd->reg.A, &fd->reg.L);
    case 0x8E: return op_adc_rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0x8F: return op_adc_rr_rr(fd, &fd->reg.A, &fd->reg.A);

    case 0x90: return op_sub_rr_rr(fd, &fd->reg.A, &fd->reg.B);
    case 0x91: return op_sub_rr_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0x92: return op_sub_rr_rr(fd, &fd->reg.A, &fd->reg.D);
    case 0x93: return op_sub_rr_rr(fd, &fd->reg.A, &fd->reg.E);
    case 0x94: return op_sub_rr_rr(fd, &fd->reg.A, &fd->reg.H);
    case 0x95: return op_sub_rr_rr(fd, &fd->reg.A, &fd->reg.L);
    case 0x96: return op_sub_rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0x97: return op_sub_rr_rr(fd, &fd->reg.A, &fd->reg.A);
    case 0x98: return op_sbc_rr_rr(fd, &fd->reg.A, &fd->reg.B);
    case 0x99: return op_sbc_rr_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0x9A: return op_sbc_rr_rr(fd, &fd->reg.A, &fd->reg.D);
    case 0x9B: return op_sbc_rr_rr(fd, &fd->reg.A, &fd->reg.E);
    case 0x9C: return op_sbc_rr_rr(fd, &fd->reg.A, &fd->reg.H);
    case 0x9D: return op_sbc_rr_rr(fd, &fd->reg.A, &fd->reg.L);
    case 0x9E: return op_sbc_rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0x9F: return op_sbc_rr_rr(fd, &fd->reg.A, &fd->reg.A);

    case 0xA0: return op_and_rr_rr(fd, &fd->reg.A, &fd->reg.B);
    case 0xA1: return op_and_rr_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0xA2: return op_and_rr_rr(fd, &fd->reg.A, &fd->reg.D);
    case 0xA3: return op_and_rr_rr(fd, &fd->reg.A, &fd->reg.E);
    case 0xA4: return op_and_rr_rr(fd, &fd->reg.A, &fd->reg.H);
    case 0xA5: return op_and_rr_rr(fd, &fd->reg.A, &fd->reg.L);
    case 0xA6: return op_and_rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0xA7: return op_and_rr_rr(fd, &fd->reg.A, &fd->reg.A);
    case 0xA8: return op_xor_rr_rr(fd, &fd->reg.A, &fd->reg.B);
    case 0xA9: return op_xor_rr_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0xAA: return op_xor_rr_rr(fd, &fd->reg.A, &fd->reg.D);
    case 0xAB: return op_xor_rr_rr(fd, &fd->reg.A, &fd->reg.E);
    case 0xAC: return op_xor_rr_rr(fd, &fd->reg.A, &fd->reg.H);
    case 0xAD: return op_xor_rr_rr(fd, &fd->reg.A, &fd->reg.L);
    case 0xAE: return op_xor_rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0xAF: return op_xor_rr_rr(fd, &fd->reg.A, &fd->reg.A);

    case 0xB0: return op_or__rr_rr(fd, &fd->reg.A, &fd->reg.B);
    case 0xB1: return op_or__rr_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0xB2: return op_or__rr_rr(fd, &fd->reg.A, &fd->reg.D);
    case 0xB3: return op_or__rr_rr(fd, &fd->reg.A, &fd->reg.E);
    case 0xB4: return op_or__rr_rr(fd, &fd->reg.A, &fd->reg.H);
    case 0xB5: return op_or__rr_rr(fd, &fd->reg.A, &fd->reg.L);
    case 0xB6: return op_or__rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0xB7: return op_or__rr_rr(fd, &fd->reg.A, &fd->reg.A);
    case 0xB8: return op_cp__rr_rr(fd, &fd->reg.A, &fd->reg.B);
    case 0xB9: return op_cp__rr_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0xBA: return op_cp__rr_rr(fd, &fd->reg.A, &fd->reg.D);
    case 0xBB: return op_cp__rr_rr(fd, &fd->reg.A, &fd->reg.E);
    case 0xBC: return op_cp__rr_rr(fd, &fd->reg.A, &fd->reg.H);
    case 0xBD: return op_cp__rr_rr(fd, &fd->reg.A, &fd->reg.L);
    case 0xBE: return op_cp__rr_WW(fd, &fd->reg.A, &fd->reg.HL);
    case 0xBF: return op_cp__rr_rr(fd, &fd->reg.A, &fd->reg.A);

    case 0xC0: return op_ret_if___(fd, COND_NZ);
    case 0xC1: return op_pop_ww___(fd, &fd->reg.BC);
    case 0xC2: return op_jp__if_AF(fd, COND_NZ, with16(op));
    case 0xC3: return op_jp__AF___(fd, with16(op));
    case 0xC4: return op_cal_if_AF(fd, COND_NZ, with16(op));
    case 0xC5: return op_psh_ww___(fd, &fd->reg.BC);
    case 0xC6: return op_add_rr_d8(fd, &fd->reg.A, with8(op));
    case 0xC7: return op_rst_d8___(fd, 0x00);
    case 0xC8: return op_ret_if___(fd, COND_Z);
    case 0xC9: return op_ret______(fd);
    case 0xCA: return op_jp__if_AF(fd, COND_Z, with16(op));
    case 0xCB: return op_cb(fd, op[1]);
    case 0xCC: return op_cal_if_AF(fd, COND_Z, with16(op));
    case 0xCD: return op_cal_AF___(fd, with16(op));
    case 0xCE: return op_adc_rr_d8(fd, &fd->reg.A, with8(op));
    case 0xCF: return op_rst_d8___(fd, 0x08);

    case 0xD0: return op_ret_if___(fd, COND_NC);
    case 0xD1: return op_pop_ww___(fd, &fd->reg.DE);
    case 0xD2: return op_jp__if_AF(fd, COND_NC, with16(op));
    case 0xD3: return OP_ILLEGAL;
    case 0xD4: return op_cal_if_AF(fd, COND_NC, with16(op));
    case 0xD5: return op_psh_ww___(fd, &fd->reg.DE);
    case 0xD6: return op_sub_rr_d8(fd, &fd->reg.A, with8(op));
    case 0xD7: return op_rst_d8___(fd, 0x10);
    case 0xD8: return op_ret_if___(fd, COND_C);
    case 0xD9: return op_rti______(fd);
    case 0xDA: return op_jp__if_AF(fd, COND_C, with16(op));
    case 0xDB: return OP_ILLEGAL;
    case 0xDC: return op_cal_if_AF(fd, COND_C, with16(op));
    case 0xDD: return OP_ILLEGAL;
    case 0xDE: return op_sbc_rr_d8(fd, &fd->reg.A, with8(op));
    case 0xDF: return op_rst_d8___(fd, 0x18);

    case 0xE0: return op_ldh_A8_rr(fd, with8(op), &fd->reg.A);
    case 0xE1: return op_pop_ww___(fd, &fd->reg.HL);
    case 0xE2: return op_ld__RR_rr(fd, &fd->reg.A, &fd->reg.C);
    case 0xE3: return OP_ILLEGAL;
    case 0xE4: return OP_ILLEGAL;
    case 0xE5: return op_psh_ww___(fd, &fd->reg.HL);
    case 0xE6: return op_and_rr_d8(fd, &fd->reg.A, with8(op));
    case 0xE7: return op_rst_d8___(fd, 0x20);
    case 0xE8: return op_add_ww_R8(fd, &fd->reg.SP, with8(op));
    case 0xE9: return op_jp__WW___(fd, &fd->reg.HL);
    case 0xEA: return op_ld__AF_rr(fd, with16(op), &fd->reg.A);
    case 0xEB: return OP_ILLEGAL;
    case 0xEC: return OP_ILLEGAL;
    case 0xED: return OP_ILLEGAL;
    case 0xEE: return op_xor_rr_d8(fd, &fd->reg.A, with8(op));
    case 0xEF: return op_rst_d8___(fd, 0x28);

    case 0xF0: return op_ldh_rr_A8(fd, &fd->reg.A, with8(op));
    case 0xF1: return op_pop_ww___(fd, &fd->reg.AF);
    case 0xF2: return op_ld__rr_RR(fd, &fd->reg.A, &fd->reg.C);
    case 0xF3: return op_int______(fd, false);
    case 0xF4: return OP_ILLEGAL;
    case 0xF5: return op_psh_ww___(fd, &fd->reg.AF);
    case 0xF6: return op_or__rr_d8(fd, &fd->reg.A, with8(op));
    case 0xF7: return op_rst_d8___(fd, 0x30);
    case 0xF8: return op_ld__ww_ww_R8(fd, &fd->reg.HL, &fd->reg.SP, with8(op));
    case 0xF9: return op_ld__ww_ww(fd, &fd->reg.SP, &fd->reg.HL);
    case 0xFA: return op_ld__rr_AF(fd, &fd->reg.A, with16(op));
    case 0xFB: return op_int______(fd, true);
    case 0xFC: return OP_ILLEGAL;
    case 0xFD: return OP_ILLEGAL;
    case 0xFE: return op_cp__rr_d8(fd, &fd->reg.A, with8(op));
    case 0xFF: return op_rst_d8___(fd, 0x38);
  }

  return OP_ILLEGAL;
}
