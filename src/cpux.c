#include "cpux.h"
#include "cpux_cb.h"
#include "cpux_do.h"
#include "fundude.h"
#include "mmux.h"

static uint8_t with8(uint8_t op[]) {
  return op[1];
}

static uint16_t with16(uint8_t op[]) {
  return (op[2] << 8) + op[1];
}

static bool cond_check(fundude* fd, cpu_cond c) {
  switch (c) {
    case CPU_COND_NZ: return !fd->cpu.FLAGS.Z;
    case CPU_COND_Z: return fd->cpu.FLAGS.Z;
    case CPU_COND_NC: return !fd->cpu.FLAGS.C;
    case CPU_COND_C: return fd->cpu.FLAGS.C;
  }
}

static cpu_result CPU_JUMP(uint16_t jump, int length, int duration, zasm z) {
  return (cpu_result){jump, (length), (duration), z};
}

static cpu_result CPU_STEP(fundude* fd, int length, int duration, zasm z) {
  return CPU_JUMP(fd->cpu.PC._ + length, length, duration, z);
}

static cpu_result CPU_UNKNOWN(fundude* fd) {
  return CPU_STEP(fd, 1, 4, zasm0("---"));
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

cpu_result op_nop(fundude* fd) {
  return CPU_STEP(fd, 1, 4, zasm0("NOP"));
}

cpu_result op_sys(fundude* fd, sys_mode mode, int length) {
  fd->mode = mode;
  return CPU_STEP(fd, length, 4, zasm1("MODE", zasma_sys_mode(mode)));
}

cpu_result op_scf(fundude* fd) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = fd->cpu.FLAGS.Z,
      .N = false,
      .H = false,
      .C = true,
  };
  return CPU_STEP(fd, 1, 4, zasm0("SCF"));
}

cpu_result op_ccf(fundude* fd) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = fd->cpu.FLAGS.Z,
      .N = false,
      .H = false,
      .C = !fd->cpu.FLAGS.C,
  };
  return CPU_STEP(fd, 1, 4, zasm0("CCF"));
}

cpu_result op_int______(fundude* fd, bool set) {
  fd->interrupt_master = set;
  return CPU_STEP(fd, 1, 4, zasm0(set ? "EI" : "DI"));
}

cpu_result op_daa_rr___(fundude* fd, cpu_reg8* dst) {
  uint8_t lb = dst->_ & 0xF;
  uint8_t hb = (dst->_ >> 4) & 0xF;
  bool carry = fd->cpu.FLAGS.C;

  if (fd->cpu.FLAGS.N) {
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
  fd->cpu.FLAGS = (cpu_flags){
      .Z = is_uint8_zero(dst->_),
      .N = fd->cpu.FLAGS.N,
      .H = false,
      .C = carry,
  };
  return CPU_STEP(fd, 1, 4, zasm1("DAA", zasma_reg8(ZASM_PLAIN, fd, dst)));
}

cpu_result op_jr__R8___(fundude* fd, uint8_t val) {
  static const int INST_LENGTH = 2;
  int offset = signed_offset(val) + INST_LENGTH;
  return CPU_JUMP(fd->cpu.PC._ + offset, INST_LENGTH, 8, zasm1("JR", zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_jr__if_R8(fundude* fd, cpu_cond c, uint8_t val) {
  static const int INST_LENGTH = 2;
  int offset = cond_check(fd, c) ? signed_offset(val) : 0;
  return CPU_JUMP(fd->cpu.PC._ + offset + INST_LENGTH, INST_LENGTH, 8,
                  zasm2("JR", zasma_cond(c), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_jp__AF___(fundude* fd, uint16_t target) {
  return CPU_JUMP(target, 3, 12, zasm1("JP", zasma_hex16(ZASM_PLAIN, target)));
}

cpu_result op_jp__if_AF(fundude* fd, cpu_cond c, uint16_t target) {
  static const int INST_LENGTH = 3;
  if (!cond_check(fd, c)) {
    target = fd->cpu.PC._ + INST_LENGTH;
  }
  return CPU_JUMP(target, INST_LENGTH, 12,
                  zasm2("JP", zasma_cond(c), zasma_hex16(ZASM_PLAIN, target)));
}

cpu_result op_jp__WW___(fundude* fd, cpu_reg16* tgt) {
  uint16_t target = mmu_get(&fd->mmu, tgt->_);
  return CPU_JUMP(target, 1, 4, zasm1("JP", zasma_reg16(ZASM_PAREN, fd, tgt)));
}

cpu_result op_ret______(fundude* fd) {
  uint16_t val = do_pop16(fd);
  return CPU_JUMP(val, 1, 8, zasm0("RET"));
}

cpu_result op_rti______(fundude* fd) {
  uint16_t val = do_pop16(fd);
  fd->interrupt_master = true;
  return CPU_JUMP(val, 1, 8, zasm0("RETI"));
}

cpu_result op_ret_if___(fundude* fd, cpu_cond c) {
  if (!cond_check(fd, c)) {
    return CPU_STEP(fd, 1, 8, zasm1("RET", zasma_cond(c)));
  }
  uint16_t val = do_pop16(fd);
  return CPU_JUMP(val, 1, 8, zasm1("RET", zasma_cond(c)));
}

cpu_result op_rst_d8___(fundude* fd, uint8_t val) {
  do_push16(fd, fd->cpu.PC._);
  return CPU_JUMP(val, 1, 32, zasm1("RST", zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_rlc_rr___(fundude* fd, cpu_reg8* tgt) {
  tgt->_ = do_rlc(fd, tgt->_);
  return CPU_STEP(fd, 1, 4, zasm1("RLCA", zasma_reg8(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_rla_rr___(fundude* fd, cpu_reg8* tgt) {
  tgt->_ = do_rl(fd, tgt->_);
  return CPU_STEP(fd, 1, 4, zasm1("RLA", zasma_reg8(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_rrc_rr___(fundude* fd, cpu_reg8* tgt) {
  tgt->_ = do_rrc(fd, tgt->_);
  return CPU_STEP(fd, 1, 4, zasm1("RRC", zasma_reg8(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_rra_rr___(fundude* fd, cpu_reg8* tgt) {
  tgt->_ = do_rr(fd, tgt->_);
  return CPU_STEP(fd, 1, 4, zasm1("RRA", zasma_reg8(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_ld__rr_d8(fundude* fd, cpu_reg8* tgt, uint8_t d8) {
  tgt->_ = d8;
  return CPU_STEP(fd, 2, 8,
                  zasm2("LD", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, d8)));
}

cpu_result op_ld__rr_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  tgt->_ = src->_;
  return CPU_STEP(fd, 1, 4,
                  zasm2("LD", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_ld__rr_RR(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  tgt->_ = mmu_get(&fd->mmu, 0xFF00 + src->_);
  return CPU_STEP(fd, 1, 8,
                  zasm2("LD", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_HIMEM, fd, src)));
}

cpu_result op_ld__RR_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  mmu_set(&fd->mmu, 0xFF00 + tgt->_, src->_);
  return CPU_STEP(fd, 1, 8,
                  zasm2("LD", zasma_reg8(ZASM_HIMEM, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_ld__rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  tgt->_ = mmu_get(&fd->mmu, src->_);
  return CPU_STEP(fd, 1, 8,
                  zasm2("LD", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_ld__ww_df(fundude* fd, cpu_reg16* tgt, uint16_t val) {
  tgt->_ = val;
  return CPU_STEP(fd, 3, 12,
                  zasm2("LD", zasma_reg16(ZASM_PLAIN, fd, tgt), zasma_hex16(ZASM_PLAIN, val)));
}

cpu_result op_ld__WW_rr(fundude* fd, cpu_reg16* tgt, cpu_reg8* src) {
  mmu_set(&fd->mmu, tgt->_, src->_);
  return CPU_STEP(fd, 1, 8,
                  zasm2("LD", zasma_reg16(ZASM_PAREN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_ld__AF_ww(fundude* fd, uint16_t a16, cpu_reg16* src) {
  mmu_set(&fd->mmu, a16, src->_);
  return CPU_STEP(fd, 3, 20,
                  zasm2("LD", zasma_hex16(ZASM_PAREN, a16), zasma_reg16(ZASM_PLAIN, fd, src)));
}

cpu_result op_ld__WW_d8(fundude* fd, cpu_reg16* tgt, uint8_t val) {
  mmu_set(&fd->mmu, tgt->_, val);
  return CPU_STEP(fd, 2, 12,
                  zasm2("LD", zasma_reg16(ZASM_PAREN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_ld__AF_rr(fundude* fd, uint16_t tgt, cpu_reg8* src) {
  mmu_set(&fd->mmu, tgt, src->_);
  return CPU_STEP(fd, 3, 16,
                  zasm2("LD", zasma_hex16(ZASM_PAREN, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_ld__rr_AF(fundude* fd, cpu_reg8* tgt, uint16_t val) {
  tgt->_ = mmu_get(&fd->mmu, val);
  return CPU_STEP(fd, 3, 16,
                  zasm2("LD", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex16(ZASM_PAREN, val)));
}

cpu_result op_ld__ww_ww(fundude* fd, cpu_reg16* tgt, cpu_reg16* src) {
  tgt->_ = src->_;
  return CPU_STEP(fd, 3, 16,
                  zasm2("LD", zasma_reg16(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_ldh_ww_R8(fundude* fd, cpu_reg16* src, uint8_t val) {
  int offset = signed_offset(val);
  fd->cpu.HL._ = src->_ + offset;
  return CPU_STEP(fd, 3, 16,
                  zasm2("LDHL", zasma_reg16(ZASM_PLAIN, fd, src), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_ldi_WW_rr(fundude* fd, cpu_reg16* tgt, cpu_reg8* src) {
  mmu_set(&fd->mmu, tgt->_++, src->_);
  return CPU_STEP(fd, 1, 8,
                  zasm2("LDI", zasma_reg16(ZASM_PAREN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_ldi_rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  tgt->_ = mmu_get(&fd->mmu, src->_++);
  return CPU_STEP(fd, 1, 8,
                  zasm2("LDI", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_ldd_WW_rr(fundude* fd, cpu_reg16* tgt, cpu_reg8* src) {
  mmu_set(&fd->mmu, tgt->_--, src->_);
  return CPU_STEP(fd, 1, 8,
                  zasm2("LDD", zasma_reg16(ZASM_PAREN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_ldd_rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  tgt->_ = mmu_get(&fd->mmu, src->_--);
  return CPU_STEP(fd, 1, 8,
                  zasm2("LDD", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_ldh_A8_rr(fundude* fd, uint8_t tgt, cpu_reg8* src) {
  mmu_set(&fd->mmu, 0xFF00 + tgt, src->_);
  return CPU_STEP(fd, 2, 12,
                  zasm2("LDH", zasma_hex8(ZASM_HIMEM, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_ldh_rr_A8(fundude* fd, cpu_reg8* tgt, uint8_t src) {
  tgt->_ = mmu_get(&fd->mmu, 0xFF00 + src);
  return CPU_STEP(fd, 2, 12,
                  zasm2("LDH", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_HIMEM, src)));
}

cpu_result op_inc_ww___(fundude* fd, cpu_reg16* tgt) {
  tgt->_++;
  return CPU_STEP(fd, 1, 8, zasm1("INC", zasma_reg16(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_inc_WW___(fundude* fd, cpu_reg16* tgt) {
  uint8_t val = mmu_get(&fd->mmu, tgt->_);

  fd->cpu.FLAGS = (cpu_flags){
      .Z = is_uint8_zero(val + 1),
      .N = false,
      .H = will_carry_from(3, val, 1),
      .C = fd->cpu.FLAGS.C,
  };
  mmu_set(&fd->mmu, tgt->_, val + 1);
  return CPU_STEP(fd, 1, 12, zasm1("INC", zasma_reg16(ZASM_PAREN, fd, tgt)));
}

cpu_result op_dec_ww___(fundude* fd, cpu_reg16* tgt) {
  tgt->_--;
  return CPU_STEP(fd, 1, 8, zasm1("DEC", zasma_reg16(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_dec_WW___(fundude* fd, cpu_reg16* tgt) {
  uint8_t val = mmu_get(&fd->mmu, tgt->_);

  fd->cpu.FLAGS = (cpu_flags){
      .Z = is_uint8_zero(val - 1),
      .N = true,
      .H = will_borrow_from(4, val, 1),
      .C = fd->cpu.FLAGS.C,
  };
  mmu_set(&fd->mmu, tgt->_, val - 1);
  return CPU_STEP(fd, 1, 12, zasm1("DEC", zasma_reg16(ZASM_PAREN, fd, tgt)));
}

cpu_result op_add_rr_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  do_add_rr(fd, tgt, src->_);
  return CPU_STEP(fd, 1, 4,
                  zasm2("ADD", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_add_rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  do_add_rr(fd, tgt, mmu_get(&fd->mmu, src->_));
  return CPU_STEP(fd, 1, 8,
                  zasm2("ADD", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_add_rr_d8(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  do_add_rr(fd, tgt, val);
  return CPU_STEP(fd, 2, 8,
                  zasm2("ADD", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_add_ww_ww(fundude* fd, cpu_reg16* tgt, cpu_reg16* src) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = fd->cpu.FLAGS.Z,
      .N = false,
      .H = will_carry_from(11, tgt->_, src->_),
      .C = will_carry_from(15, tgt->_, src->_),
  };
  tgt->_ += src->_;
  return CPU_STEP(fd, 1, 8,
                  zasm2("ADD", zasma_reg16(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PLAIN, fd, src)));
}

cpu_result op_add_ww_R8(fundude* fd, cpu_reg16* tgt, uint8_t val) {
  int offset = signed_offset(val);
  fd->cpu.FLAGS = (cpu_flags){
      .Z = false,
      .N = false,
      .H = will_carry_from(11, tgt->_, offset),
      .C = will_carry_from(15, tgt->_, offset),
  };
  tgt->_ += offset;
  return CPU_STEP(fd, 2, 16,
                  zasm2("ADD", zasma_reg16(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_adc_rr_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  do_add_rr(fd, tgt, fd->cpu.FLAGS.C + src->_);
  return CPU_STEP(fd, 1, 4,
                  zasm2("ADC", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_adc_rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  do_add_rr(fd, tgt, fd->cpu.FLAGS.C + mmu_get(&fd->mmu, src->_));
  return CPU_STEP(fd, 1, 8,
                  zasm2("ADC", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_adc_rr_d8(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  do_add_rr(fd, tgt, fd->cpu.FLAGS.C + val);
  return CPU_STEP(fd, 1, 4,
                  zasm2("ADC", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_sub_rr_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  do_sub_rr(fd, tgt, src->_);
  return CPU_STEP(fd, 1, 4,
                  zasm2("SUB", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_sub_rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  do_sub_rr(fd, tgt, mmu_get(&fd->mmu, src->_));
  return CPU_STEP(fd, 1, 8,
                  zasm2("SUB", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_sub_rr_d8(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  do_sub_rr(fd, tgt, val);
  return CPU_STEP(fd, 2, 8,
                  zasm2("SUB", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_sbc_rr_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  do_sub_rr(fd, tgt, fd->cpu.FLAGS.C + src->_);
  return CPU_STEP(fd, 1, 4,
                  zasm2("SBC", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_sbc_rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  do_sub_rr(fd, tgt, fd->cpu.FLAGS.C + mmu_get(&fd->mmu, src->_));
  return CPU_STEP(fd, 1, 8,
                  zasm2("SBC", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_sbc_rr_d8(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  do_sub_rr(fd, tgt, fd->cpu.FLAGS.C + val);
  return CPU_STEP(fd, 1, 8,
                  zasm2("SBC", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_and_rr_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  do_and_rr(fd, tgt, src->_);
  return CPU_STEP(fd, 1, 4,
                  zasm2("AND", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_and_rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  do_and_rr(fd, tgt, mmu_get(&fd->mmu, src->_));
  return CPU_STEP(fd, 1, 8,
                  zasm2("AND", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_and_rr_d8(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  do_and_rr(fd, tgt, val);
  return CPU_STEP(fd, 2, 8,
                  zasm2("AND", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_or__rr_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  do_or__rr(fd, tgt, src->_);
  return CPU_STEP(fd, 1, 4,
                  zasm2("OR", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_or__rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  do_or__rr(fd, tgt, mmu_get(&fd->mmu, src->_));
  return CPU_STEP(fd, 1, 8,
                  zasm2("OR", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_or__rr_d8(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  do_or__rr(fd, tgt, val);
  return CPU_STEP(fd, 2, 8,
                  zasm2("OR", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_xor_rr_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  do_xor_rr(fd, tgt, src->_);
  return CPU_STEP(fd, 1, 4,
                  zasm2("XOR", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_xor_rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  do_xor_rr(fd, tgt, mmu_get(&fd->mmu, src->_));
  return CPU_STEP(fd, 1, 8,
                  zasm2("XOR", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_xor_rr_d8(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  do_xor_rr(fd, tgt, val);
  return CPU_STEP(fd, 2, 8,
                  zasm2("XOR", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_cp__rr_rr(fundude* fd, cpu_reg8* tgt, cpu_reg8* src) {
  do_cp__rr(fd, tgt, src->_);
  return CPU_STEP(fd, 1, 4,
                  zasm2("CP", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg8(ZASM_PLAIN, fd, src)));
}

cpu_result op_cp__rr_WW(fundude* fd, cpu_reg8* tgt, cpu_reg16* src) {
  do_cp__rr(fd, tgt, mmu_get(&fd->mmu, src->_));
  return CPU_STEP(fd, 1, 8,
                  zasm2("CP", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_reg16(ZASM_PAREN, fd, src)));
}

cpu_result op_cp__rr_d8(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  do_cp__rr(fd, tgt, val);
  return CPU_STEP(fd, 2, 8,
                  zasm2("CP", zasma_reg8(ZASM_PLAIN, fd, tgt), zasma_hex8(ZASM_PLAIN, val)));
}

cpu_result op_inc_rr___(fundude* fd, cpu_reg8* tgt) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = is_uint8_zero(tgt->_ + 1),
      .N = false,
      .H = will_carry_from(3, tgt->_, 1),
      .C = fd->cpu.FLAGS.C,
  };
  tgt->_++;
  return CPU_STEP(fd, 1, 4, zasm1("INC", zasma_reg8(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_dec_rr___(fundude* fd, cpu_reg8* tgt) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = is_uint8_zero(tgt->_ - 1),
      .N = true,
      .H = will_carry_from(3, tgt->_, 1),
      .C = fd->cpu.FLAGS.C,
  };
  tgt->_--;
  return CPU_STEP(fd, 1, 4, zasm1("DEC", zasma_reg8(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_cpl_rr___(fundude* fd, cpu_reg8* tgt) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = fd->cpu.FLAGS.Z,
      .N = true,
      .H = true,
      .C = fd->cpu.FLAGS.C,
  };
  return CPU_STEP(fd, 1, 4, zasm1("CPL", zasma_reg8(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_pop_ww___(fundude* fd, cpu_reg16* tgt) {
  tgt->_ = do_pop16(fd);
  return CPU_STEP(fd, 1, 12, zasm1("POP", zasma_reg16(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_psh_ww___(fundude* fd, cpu_reg16* tgt) {
  do_push16(fd, tgt->_);
  return CPU_STEP(fd, 1, 16, zasm1("PUSH", zasma_reg16(ZASM_PLAIN, fd, tgt)));
}

cpu_result op_cal_AF___(fundude* fd, uint16_t val) {
  do_push16(fd, fd->cpu.PC._ + 3);
  return CPU_JUMP(val, 3, 12, zasm1("CALL", zasma_hex16(ZASM_PLAIN, val)));
}

cpu_result op_cal_if_AF(fundude* fd, cpu_cond c, uint16_t val) {
  if (!cond_check(fd, c)) {
    return CPU_STEP(fd, 3, 12, zasm2("CALL", zasma_cond(c), zasma_hex16(ZASM_PLAIN, val)));
  }
  do_push16(fd, fd->cpu.PC._ + 3);
  return CPU_JUMP(val, 3, 12, zasm2("CALL", zasma_cond(c), zasma_hex16(ZASM_PLAIN, val)));
}

cpu_result op_cb(fundude* fd, uint8_t op) {
  cpu_reg8* tgt = cb_tgt(fd, op);
  if (tgt) {
    cb_result res = cb_run(fd, op, tgt->_);
    tgt->_ = res.val;
    return CPU_STEP(fd, 2, 8, zasm1(res.name, zasma_reg8(ZASM_PLAIN, fd, tgt)));
  } else {
    cb_result res = cb_run(fd, op, mmu_get(&fd->mmu, fd->cpu.HL._));
    mmu_set(&fd->mmu, fd->cpu.HL._, res.val);
    return CPU_STEP(fd, 2, 16, zasm1(res.name, zasma_reg16(ZASM_PAREN, fd, &fd->cpu.HL)));
  }
}

cpu_result cpu_step(fundude* fd, uint8_t op[]) {
  switch (op[0]) {
    case 0x00: return op_nop(fd);
    case 0x01: return op_ld__ww_df(fd, &fd->cpu.BC, with16(op));
    case 0x02: return op_ld__WW_rr(fd, &fd->cpu.BC, &fd->cpu.A);
    case 0x03: return op_inc_ww___(fd, &fd->cpu.BC);
    case 0x04: return op_inc_rr___(fd, &fd->cpu.B);
    case 0x05: return op_dec_rr___(fd, &fd->cpu.B);
    case 0x06: return op_ld__rr_d8(fd, &fd->cpu.B, with8(op));
    case 0x07: return op_rlc_rr___(fd, &fd->cpu.A);
    case 0x08: return op_ld__AF_ww(fd, with16(op), &fd->cpu.SP);
    case 0x09: return op_add_ww_ww(fd, &fd->cpu.HL, &fd->cpu.BC);
    case 0x0A: return op_ld__rr_WW(fd, &fd->cpu.A, &fd->cpu.BC);
    case 0x0B: return op_dec_ww___(fd, &fd->cpu.BC);
    case 0x0C: return op_inc_rr___(fd, &fd->cpu.C);
    case 0x0D: return op_dec_rr___(fd, &fd->cpu.C);
    case 0x0E: return op_ld__rr_d8(fd, &fd->cpu.C, with8(op));
    case 0x0F: return op_rrc_rr___(fd, &fd->cpu.A);

    case 0x10: return op_sys(fd, SYS_STOP, 2);
    case 0x11: return op_ld__ww_df(fd, &fd->cpu.DE, with16(op));
    case 0x12: return op_ld__WW_rr(fd, &fd->cpu.DE, &fd->cpu.A);
    case 0x13: return op_inc_ww___(fd, &fd->cpu.DE);
    case 0x14: return op_inc_rr___(fd, &fd->cpu.D);
    case 0x15: return op_dec_rr___(fd, &fd->cpu.D);
    case 0x16: return op_ld__rr_d8(fd, &fd->cpu.D, with8(op));
    case 0x17: return op_rla_rr___(fd, &fd->cpu.A);
    case 0x18: return op_jr__R8___(fd, with8(op));
    case 0x19: return op_add_ww_ww(fd, &fd->cpu.HL, &fd->cpu.DE);
    case 0x1A: return op_ld__rr_WW(fd, &fd->cpu.A, &fd->cpu.DE);
    case 0x1B: return op_dec_ww___(fd, &fd->cpu.DE);
    case 0x1C: return op_inc_rr___(fd, &fd->cpu.E);
    case 0x1D: return op_dec_rr___(fd, &fd->cpu.E);
    case 0x1E: return op_ld__rr_d8(fd, &fd->cpu.E, with8(op));
    case 0x1F: return op_rra_rr___(fd, &fd->cpu.A);

    case 0x20: return op_jr__if_R8(fd, CPU_COND_NZ, with8(op));
    case 0x21: return op_ld__ww_df(fd, &fd->cpu.HL, with16(op));
    case 0x22: return op_ldi_WW_rr(fd, &fd->cpu.HL, &fd->cpu.A);
    case 0x23: return op_inc_ww___(fd, &fd->cpu.HL);
    case 0x24: return op_inc_rr___(fd, &fd->cpu.H);
    case 0x25: return op_dec_rr___(fd, &fd->cpu.H);
    case 0x26: return op_ld__rr_d8(fd, &fd->cpu.H, with8(op));
    case 0x27: return op_daa_rr___(fd, &fd->cpu.A);
    case 0x28: return op_jr__if_R8(fd, CPU_COND_Z, with8(op));
    case 0x29: return op_add_ww_ww(fd, &fd->cpu.HL, &fd->cpu.HL);
    case 0x2A: return op_ldi_rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0x2B: return op_dec_ww___(fd, &fd->cpu.HL);
    case 0x2C: return op_inc_rr___(fd, &fd->cpu.L);
    case 0x2D: return op_dec_rr___(fd, &fd->cpu.L);
    case 0x2E: return op_ld__rr_d8(fd, &fd->cpu.L, with8(op));
    case 0x2F: return op_cpl_rr___(fd, &fd->cpu.A);

    case 0x30: return op_jr__if_R8(fd, CPU_COND_NC, with8(op));
    case 0x31: return op_ld__ww_df(fd, &fd->cpu.SP, with16(op));
    case 0x32: return op_ldd_WW_rr(fd, &fd->cpu.HL, &fd->cpu.A);
    case 0x33: return op_inc_ww___(fd, &fd->cpu.SP);
    case 0x34: return op_inc_WW___(fd, &fd->cpu.HL);
    case 0x35: return op_dec_WW___(fd, &fd->cpu.HL);
    case 0x36: return op_ld__WW_d8(fd, &fd->cpu.HL, with8(op));
    case 0x37: return op_scf(fd);
    case 0x38: return op_jr__if_R8(fd, CPU_COND_C, with8(op));
    case 0x39: return op_add_ww_ww(fd, &fd->cpu.HL, &fd->cpu.SP);
    case 0x3A: return op_ldd_rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0x3B: return op_dec_ww___(fd, &fd->cpu.SP);
    case 0x3C: return op_inc_rr___(fd, &fd->cpu.A);
    case 0x3D: return op_dec_rr___(fd, &fd->cpu.A);
    case 0x3E: return op_ld__rr_d8(fd, &fd->cpu.A, with8(op));
    case 0x3F: return op_ccf(fd);

    case 0x40: return op_ld__rr_rr(fd, &fd->cpu.B, &fd->cpu.B);
    case 0x41: return op_ld__rr_rr(fd, &fd->cpu.B, &fd->cpu.C);
    case 0x42: return op_ld__rr_rr(fd, &fd->cpu.B, &fd->cpu.D);
    case 0x43: return op_ld__rr_rr(fd, &fd->cpu.B, &fd->cpu.E);
    case 0x44: return op_ld__rr_rr(fd, &fd->cpu.B, &fd->cpu.H);
    case 0x45: return op_ld__rr_rr(fd, &fd->cpu.B, &fd->cpu.L);
    case 0x46: return op_ld__rr_WW(fd, &fd->cpu.B, &fd->cpu.HL);
    case 0x47: return op_ld__rr_rr(fd, &fd->cpu.B, &fd->cpu.A);
    case 0x48: return op_ld__rr_rr(fd, &fd->cpu.C, &fd->cpu.B);
    case 0x49: return op_ld__rr_rr(fd, &fd->cpu.C, &fd->cpu.C);
    case 0x4A: return op_ld__rr_rr(fd, &fd->cpu.C, &fd->cpu.D);
    case 0x4B: return op_ld__rr_rr(fd, &fd->cpu.C, &fd->cpu.E);
    case 0x4C: return op_ld__rr_rr(fd, &fd->cpu.C, &fd->cpu.H);
    case 0x4D: return op_ld__rr_rr(fd, &fd->cpu.C, &fd->cpu.L);
    case 0x4E: return op_ld__rr_WW(fd, &fd->cpu.C, &fd->cpu.HL);
    case 0x4F: return op_ld__rr_rr(fd, &fd->cpu.C, &fd->cpu.A);

    case 0x50: return op_ld__rr_rr(fd, &fd->cpu.D, &fd->cpu.B);
    case 0x51: return op_ld__rr_rr(fd, &fd->cpu.D, &fd->cpu.C);
    case 0x52: return op_ld__rr_rr(fd, &fd->cpu.D, &fd->cpu.D);
    case 0x53: return op_ld__rr_rr(fd, &fd->cpu.D, &fd->cpu.E);
    case 0x54: return op_ld__rr_rr(fd, &fd->cpu.D, &fd->cpu.H);
    case 0x55: return op_ld__rr_rr(fd, &fd->cpu.D, &fd->cpu.L);
    case 0x56: return op_ld__rr_WW(fd, &fd->cpu.D, &fd->cpu.HL);
    case 0x57: return op_ld__rr_rr(fd, &fd->cpu.D, &fd->cpu.A);
    case 0x58: return op_ld__rr_rr(fd, &fd->cpu.E, &fd->cpu.B);
    case 0x59: return op_ld__rr_rr(fd, &fd->cpu.E, &fd->cpu.C);
    case 0x5A: return op_ld__rr_rr(fd, &fd->cpu.E, &fd->cpu.D);
    case 0x5B: return op_ld__rr_rr(fd, &fd->cpu.E, &fd->cpu.E);
    case 0x5C: return op_ld__rr_rr(fd, &fd->cpu.E, &fd->cpu.H);
    case 0x5D: return op_ld__rr_rr(fd, &fd->cpu.E, &fd->cpu.L);
    case 0x5E: return op_ld__rr_WW(fd, &fd->cpu.E, &fd->cpu.HL);
    case 0x5F: return op_ld__rr_rr(fd, &fd->cpu.E, &fd->cpu.A);

    case 0x60: return op_ld__rr_rr(fd, &fd->cpu.H, &fd->cpu.B);
    case 0x61: return op_ld__rr_rr(fd, &fd->cpu.H, &fd->cpu.C);
    case 0x62: return op_ld__rr_rr(fd, &fd->cpu.H, &fd->cpu.D);
    case 0x63: return op_ld__rr_rr(fd, &fd->cpu.H, &fd->cpu.E);
    case 0x64: return op_ld__rr_rr(fd, &fd->cpu.H, &fd->cpu.H);
    case 0x65: return op_ld__rr_rr(fd, &fd->cpu.H, &fd->cpu.L);
    case 0x66: return op_ld__rr_WW(fd, &fd->cpu.H, &fd->cpu.HL);
    case 0x67: return op_ld__rr_rr(fd, &fd->cpu.H, &fd->cpu.A);
    case 0x68: return op_ld__rr_rr(fd, &fd->cpu.L, &fd->cpu.B);
    case 0x69: return op_ld__rr_rr(fd, &fd->cpu.L, &fd->cpu.C);
    case 0x6A: return op_ld__rr_rr(fd, &fd->cpu.L, &fd->cpu.D);
    case 0x6B: return op_ld__rr_rr(fd, &fd->cpu.L, &fd->cpu.E);
    case 0x6C: return op_ld__rr_rr(fd, &fd->cpu.L, &fd->cpu.H);
    case 0x6D: return op_ld__rr_rr(fd, &fd->cpu.L, &fd->cpu.L);
    case 0x6E: return op_ld__rr_WW(fd, &fd->cpu.L, &fd->cpu.HL);
    case 0x6F: return op_ld__rr_rr(fd, &fd->cpu.L, &fd->cpu.A);

    case 0x70: return op_ld__WW_rr(fd, &fd->cpu.HL, &fd->cpu.B);
    case 0x71: return op_ld__WW_rr(fd, &fd->cpu.HL, &fd->cpu.C);
    case 0x72: return op_ld__WW_rr(fd, &fd->cpu.HL, &fd->cpu.D);
    case 0x73: return op_ld__WW_rr(fd, &fd->cpu.HL, &fd->cpu.E);
    case 0x74: return op_ld__WW_rr(fd, &fd->cpu.HL, &fd->cpu.H);
    case 0x75: return op_ld__WW_rr(fd, &fd->cpu.HL, &fd->cpu.L);
    case 0x76: return op_sys(fd, SYS_HALT, 1);
    case 0x77: return op_ld__WW_rr(fd, &fd->cpu.HL, &fd->cpu.A);
    case 0x78: return op_ld__rr_rr(fd, &fd->cpu.A, &fd->cpu.B);
    case 0x79: return op_ld__rr_rr(fd, &fd->cpu.A, &fd->cpu.C);
    case 0x7A: return op_ld__rr_rr(fd, &fd->cpu.A, &fd->cpu.D);
    case 0x7B: return op_ld__rr_rr(fd, &fd->cpu.A, &fd->cpu.E);
    case 0x7C: return op_ld__rr_rr(fd, &fd->cpu.A, &fd->cpu.H);
    case 0x7D: return op_ld__rr_rr(fd, &fd->cpu.A, &fd->cpu.L);
    case 0x7E: return op_ld__rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0x7F: return op_ld__rr_rr(fd, &fd->cpu.A, &fd->cpu.A);

    case 0x80: return op_add_rr_rr(fd, &fd->cpu.A, &fd->cpu.B);
    case 0x81: return op_add_rr_rr(fd, &fd->cpu.A, &fd->cpu.C);
    case 0x82: return op_add_rr_rr(fd, &fd->cpu.A, &fd->cpu.D);
    case 0x83: return op_add_rr_rr(fd, &fd->cpu.A, &fd->cpu.E);
    case 0x84: return op_add_rr_rr(fd, &fd->cpu.A, &fd->cpu.H);
    case 0x85: return op_add_rr_rr(fd, &fd->cpu.A, &fd->cpu.L);
    case 0x86: return op_add_rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0x87: return op_add_rr_rr(fd, &fd->cpu.A, &fd->cpu.A);
    case 0x88: return op_adc_rr_rr(fd, &fd->cpu.A, &fd->cpu.B);
    case 0x89: return op_adc_rr_rr(fd, &fd->cpu.A, &fd->cpu.C);
    case 0x8A: return op_adc_rr_rr(fd, &fd->cpu.A, &fd->cpu.D);
    case 0x8B: return op_adc_rr_rr(fd, &fd->cpu.A, &fd->cpu.E);
    case 0x8C: return op_adc_rr_rr(fd, &fd->cpu.A, &fd->cpu.H);
    case 0x8D: return op_adc_rr_rr(fd, &fd->cpu.A, &fd->cpu.L);
    case 0x8E: return op_adc_rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0x8F: return op_adc_rr_rr(fd, &fd->cpu.A, &fd->cpu.A);

    case 0x90: return op_sub_rr_rr(fd, &fd->cpu.A, &fd->cpu.B);
    case 0x91: return op_sub_rr_rr(fd, &fd->cpu.A, &fd->cpu.C);
    case 0x92: return op_sub_rr_rr(fd, &fd->cpu.A, &fd->cpu.D);
    case 0x93: return op_sub_rr_rr(fd, &fd->cpu.A, &fd->cpu.E);
    case 0x94: return op_sub_rr_rr(fd, &fd->cpu.A, &fd->cpu.H);
    case 0x95: return op_sub_rr_rr(fd, &fd->cpu.A, &fd->cpu.L);
    case 0x96: return op_sub_rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0x97: return op_sub_rr_rr(fd, &fd->cpu.A, &fd->cpu.A);
    case 0x98: return op_sbc_rr_rr(fd, &fd->cpu.A, &fd->cpu.B);
    case 0x99: return op_sbc_rr_rr(fd, &fd->cpu.A, &fd->cpu.C);
    case 0x9A: return op_sbc_rr_rr(fd, &fd->cpu.A, &fd->cpu.D);
    case 0x9B: return op_sbc_rr_rr(fd, &fd->cpu.A, &fd->cpu.E);
    case 0x9C: return op_sbc_rr_rr(fd, &fd->cpu.A, &fd->cpu.H);
    case 0x9D: return op_sbc_rr_rr(fd, &fd->cpu.A, &fd->cpu.L);
    case 0x9E: return op_sbc_rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0x9F: return op_sbc_rr_rr(fd, &fd->cpu.A, &fd->cpu.A);

    case 0xA0: return op_and_rr_rr(fd, &fd->cpu.A, &fd->cpu.B);
    case 0xA1: return op_and_rr_rr(fd, &fd->cpu.A, &fd->cpu.C);
    case 0xA2: return op_and_rr_rr(fd, &fd->cpu.A, &fd->cpu.D);
    case 0xA3: return op_and_rr_rr(fd, &fd->cpu.A, &fd->cpu.E);
    case 0xA4: return op_and_rr_rr(fd, &fd->cpu.A, &fd->cpu.H);
    case 0xA5: return op_and_rr_rr(fd, &fd->cpu.A, &fd->cpu.L);
    case 0xA6: return op_and_rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0xA7: return op_and_rr_rr(fd, &fd->cpu.A, &fd->cpu.A);
    case 0xA8: return op_xor_rr_rr(fd, &fd->cpu.A, &fd->cpu.B);
    case 0xA9: return op_xor_rr_rr(fd, &fd->cpu.A, &fd->cpu.C);
    case 0xAA: return op_xor_rr_rr(fd, &fd->cpu.A, &fd->cpu.D);
    case 0xAB: return op_xor_rr_rr(fd, &fd->cpu.A, &fd->cpu.E);
    case 0xAC: return op_xor_rr_rr(fd, &fd->cpu.A, &fd->cpu.H);
    case 0xAD: return op_xor_rr_rr(fd, &fd->cpu.A, &fd->cpu.L);
    case 0xAE: return op_xor_rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0xAF: return op_xor_rr_rr(fd, &fd->cpu.A, &fd->cpu.A);

    case 0xB0: return op_or__rr_rr(fd, &fd->cpu.A, &fd->cpu.B);
    case 0xB1: return op_or__rr_rr(fd, &fd->cpu.A, &fd->cpu.C);
    case 0xB2: return op_or__rr_rr(fd, &fd->cpu.A, &fd->cpu.D);
    case 0xB3: return op_or__rr_rr(fd, &fd->cpu.A, &fd->cpu.E);
    case 0xB4: return op_or__rr_rr(fd, &fd->cpu.A, &fd->cpu.H);
    case 0xB5: return op_or__rr_rr(fd, &fd->cpu.A, &fd->cpu.L);
    case 0xB6: return op_or__rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0xB7: return op_or__rr_rr(fd, &fd->cpu.A, &fd->cpu.A);
    case 0xB8: return op_cp__rr_rr(fd, &fd->cpu.A, &fd->cpu.B);
    case 0xB9: return op_cp__rr_rr(fd, &fd->cpu.A, &fd->cpu.C);
    case 0xBA: return op_cp__rr_rr(fd, &fd->cpu.A, &fd->cpu.D);
    case 0xBB: return op_cp__rr_rr(fd, &fd->cpu.A, &fd->cpu.E);
    case 0xBC: return op_cp__rr_rr(fd, &fd->cpu.A, &fd->cpu.H);
    case 0xBD: return op_cp__rr_rr(fd, &fd->cpu.A, &fd->cpu.L);
    case 0xBE: return op_cp__rr_WW(fd, &fd->cpu.A, &fd->cpu.HL);
    case 0xBF: return op_cp__rr_rr(fd, &fd->cpu.A, &fd->cpu.A);

    case 0xC0: return op_ret_if___(fd, CPU_COND_NZ);
    case 0xC1: return op_pop_ww___(fd, &fd->cpu.BC);
    case 0xC2: return op_jp__if_AF(fd, CPU_COND_NZ, with16(op));
    case 0xC3: return op_jp__AF___(fd, with16(op));
    case 0xC4: return op_cal_if_AF(fd, CPU_COND_NZ, with16(op));
    case 0xC5: return op_psh_ww___(fd, &fd->cpu.BC);
    case 0xC6: return op_add_rr_d8(fd, &fd->cpu.A, with8(op));
    case 0xC7: return op_rst_d8___(fd, 0x00);
    case 0xC8: return op_ret_if___(fd, CPU_COND_Z);
    case 0xC9: return op_ret______(fd);
    case 0xCA: return op_jp__if_AF(fd, CPU_COND_Z, with16(op));
    case 0xCB: return op_cb(fd, op[1]);
    case 0xCC: return op_cal_if_AF(fd, CPU_COND_Z, with16(op));
    case 0xCD: return op_cal_AF___(fd, with16(op));
    case 0xCE: return op_adc_rr_d8(fd, &fd->cpu.A, with8(op));
    case 0xCF: return op_rst_d8___(fd, 0x08);

    case 0xD0: return op_ret_if___(fd, CPU_COND_NC);
    case 0xD1: return op_pop_ww___(fd, &fd->cpu.DE);
    case 0xD2: return op_jp__if_AF(fd, CPU_COND_NC, with16(op));
    case 0xD3: return CPU_UNKNOWN(fd);
    case 0xD4: return op_cal_if_AF(fd, CPU_COND_NC, with16(op));
    case 0xD5: return op_psh_ww___(fd, &fd->cpu.DE);
    case 0xD6: return op_sub_rr_d8(fd, &fd->cpu.A, with8(op));
    case 0xD7: return op_rst_d8___(fd, 0x10);
    case 0xD8: return op_ret_if___(fd, CPU_COND_C);
    case 0xD9: return op_rti______(fd);
    case 0xDA: return op_jp__if_AF(fd, CPU_COND_C, with16(op));
    case 0xDB: return CPU_UNKNOWN(fd);
    case 0xDC: return op_cal_if_AF(fd, CPU_COND_C, with16(op));
    case 0xDD: return CPU_UNKNOWN(fd);
    case 0xDE: return op_sbc_rr_d8(fd, &fd->cpu.A, with8(op));
    case 0xDF: return op_rst_d8___(fd, 0x18);

    case 0xE0: return op_ldh_A8_rr(fd, with8(op), &fd->cpu.A);
    case 0xE1: return op_pop_ww___(fd, &fd->cpu.HL);
    case 0xE2: return op_ld__RR_rr(fd, &fd->cpu.C, &fd->cpu.A);
    case 0xE3: return CPU_UNKNOWN(fd);
    case 0xE4: return CPU_UNKNOWN(fd);
    case 0xE5: return op_psh_ww___(fd, &fd->cpu.HL);
    case 0xE6: return op_and_rr_d8(fd, &fd->cpu.A, with8(op));
    case 0xE7: return op_rst_d8___(fd, 0x20);
    case 0xE8: return op_add_ww_R8(fd, &fd->cpu.SP, with8(op));
    case 0xE9: return op_jp__WW___(fd, &fd->cpu.HL);
    case 0xEA: return op_ld__AF_rr(fd, with16(op), &fd->cpu.A);
    case 0xEB: return CPU_UNKNOWN(fd);
    case 0xEC: return CPU_UNKNOWN(fd);
    case 0xED: return CPU_UNKNOWN(fd);
    case 0xEE: return op_xor_rr_d8(fd, &fd->cpu.A, with8(op));
    case 0xEF: return op_rst_d8___(fd, 0x28);

    case 0xF0: return op_ldh_rr_A8(fd, &fd->cpu.A, with8(op));
    case 0xF1: return op_pop_ww___(fd, &fd->cpu.AF);
    case 0xF2: return op_ld__rr_RR(fd, &fd->cpu.A, &fd->cpu.C);
    case 0xF3: return op_int______(fd, false);
    case 0xF4: return CPU_UNKNOWN(fd);
    case 0xF5: return op_psh_ww___(fd, &fd->cpu.AF);
    case 0xF6: return op_or__rr_d8(fd, &fd->cpu.A, with8(op));
    case 0xF7: return op_rst_d8___(fd, 0x30);
    case 0xF8: return op_ldh_ww_R8(fd, &fd->cpu.SP, with8(op));
    case 0xF9: return op_ld__ww_ww(fd, &fd->cpu.SP, &fd->cpu.HL);
    case 0xFA: return op_ld__rr_AF(fd, &fd->cpu.A, with16(op));
    case 0xFB: return op_int______(fd, true);
    case 0xFC: return CPU_UNKNOWN(fd);
    case 0xFD: return CPU_UNKNOWN(fd);
    case 0xFE: return op_cp__rr_d8(fd, &fd->cpu.A, with8(op));
    case 0xFF: return op_rst_d8___(fd, 0x38);
  }

  return CPU_UNKNOWN(fd);
}
