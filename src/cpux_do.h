#include "fundude.h"

bool is_uint8_zero(int val);
bool will_carry_into(int bit, int a, int b);
bool will_borrow_from(int bit, int a, int b);

uint8_t flag_shift(fundude* fd, uint8_t val, bool C);

void do_push16(fundude* fd, uint16_t val);
uint16_t do_pop16(fundude* fd);

void do_and_rr(fundude* fd, cpu_reg8* tgt, uint8_t val);
void do_or__rr(fundude* fd, cpu_reg8* tgt, uint8_t val);
void do_xor_rr(fundude* fd, cpu_reg8* tgt, uint8_t val);
void do_cp__rr(fundude* fd, cpu_reg8* tgt, uint8_t val);
void do_add_rr(fundude* fd, cpu_reg8* tgt, uint8_t val);
void do_adc_rr(fundude* fd, cpu_reg8* tgt, uint8_t val);
void do_sub_rr(fundude* fd, cpu_reg8* tgt, uint8_t val);
void do_sbc_rr(fundude* fd, cpu_reg8* tgt, uint8_t val);

uint8_t do_rlc(fundude* fd, uint8_t val);
uint8_t do_rrc(fundude* fd, uint8_t val);
uint8_t do_rl(fundude* fd, uint8_t val);
uint8_t do_rr(fundude* fd, uint8_t val);
