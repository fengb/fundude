#include "fundude.h"

bool is_uint8_zero(int val);
bool will_carry_from(int bit, int a, int b);
bool will_borrow_from(int bit, int a, int b);

void do_push(fundude* fd, uint8_t val);
uint8_t do_pop(fundude* fd);

void do_and_rr(fundude* fd, reg8* tgt, uint8_t val);
void do_or__rr(fundude* fd, reg8* tgt, uint8_t val);
void do_xor_rr(fundude* fd, reg8* tgt, uint8_t val);
void do_cp__rr(fundude* fd, reg8* tgt, uint8_t val);
void do_add_rr(fundude* fd, reg8* tgt, uint8_t val);
void do_sub_rr(fundude* fd, reg8* tgt, uint8_t val);

void do_rlc(fundude* fd, uint8_t* tgt);
void do_rrc(fundude* fd, uint8_t* tgt);
void do_rl(fundude* fd, uint8_t* tgt);
void do_rr(fundude* fd, uint8_t* tgt);
