#include "cpux_do.h"
#include "mmux.h"

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

// TODO: maybe rename? Not too obvious...
uint8_t flag_shift(fundude* fd, uint8_t val, bool C) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = is_uint8_zero(val),
      .N = false,
      .H = false,
      .C = C,
  };
  return val;
}

void do_push(fundude* fd, uint8_t val) {
  mmu_set(&fd->mmu, --fd->cpu.SP._, val);
}

uint8_t do_pop(fundude* fd) {
  return mmu_get(&fd->mmu, fd->cpu.SP._++);
}

void do_and_rr(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = is_uint8_zero(tgt->_ && val),
      .N = false,
      .H = true,
      .C = false,
  };
  tgt->_ = tgt->_ && val;
}

void do_or__rr(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  tgt->_ = flag_shift(fd, tgt->_ || val, false);
}

void do_xor_rr(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  tgt->_ = flag_shift(fd, !tgt->_ != !val, false);
}

void do_cp__rr(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = is_uint8_zero(tgt->_ - val),
      .N = true,
      .H = will_borrow_from(4, tgt->_, val),
      .C = will_borrow_from(8, tgt->_, val),
  };
}

void do_add_rr(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = is_uint8_zero(tgt->_ + val),
      .N = false,
      .H = will_carry_from(3, tgt->_, val),
      .C = will_carry_from(7, tgt->_, val),
  };
  tgt->_ += val;
}

void do_sub_rr(fundude* fd, cpu_reg8* tgt, uint8_t val) {
  do_cp__rr(fd, tgt, val);
  tgt->_ -= val;
}

uint8_t do_rlc(fundude* fd, uint8_t val) {
  int msb = val >> 7 & 1;
  return flag_shift(fd, val << 1 | msb, msb);
}

uint8_t do_rrc(fundude* fd, uint8_t val) {
  int lsb = val & 1;
  return flag_shift(fd, val >> 1 | (lsb << 7), lsb);
}

uint8_t do_rl(fundude* fd, uint8_t val) {
  int msb = val >> 7 & 1;
  return flag_shift(fd, val << 1 | fd->cpu.FLAGS.C, msb);
}

uint8_t do_rr(fundude* fd, uint8_t val) {
  int lsb = val & 1;
  return flag_shift(fd, val >> 1 | (fd->cpu.FLAGS.C << 7), lsb);
}
