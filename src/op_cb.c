#include <stdlib.h>
#include "debug.h"
#include "op_do.h"

char* cb_rlc(fundude* fd, uint8_t* tgt) {
  do_rlc(fd, tgt);
  return "RLC";
}

char* cb_rrc(fundude* fd, uint8_t* tgt) {
  do_rrc(fd, tgt);
  return "RRC";
}

char* cb_rl(fundude* fd, uint8_t* tgt) {
  do_rl(fd, tgt);
  return "RL";
}

char* cb_rr(fundude* fd, uint8_t* tgt) {
  do_rr(fd, tgt);
  return "RR";
}

char* cb_sla(fundude* fd, uint8_t* tgt) {
  *tgt = flag_shift(fd, *tgt << 1, *tgt >> 7);
  return "SLA";
}

char* cb_sra(fundude* fd, uint8_t* tgt) {
  *tgt = flag_shift(fd, *tgt >> 1, *tgt & 1);
  return "SRA";
}

uint8_t* cb_tgt(fundude* fd, uint8_t op) {
  switch (op & 7) {
    case 0: return &fd->reg.B._;
    case 1: return &fd->reg.C._;
    case 2: return &fd->reg.D._;
    case 3: return &fd->reg.E._;
    case 4: return &fd->reg.H._;
    case 5: return &fd->reg.L._;
    case 6: return NULL;
    case 7: return &fd->reg.A._;
  }

  return NULL;
}

char* cb_run(fundude* fd, uint8_t op, uint8_t* tgt) {
  switch (op & 0xF8) {
    case 0x00: return cb_rlc(fd, tgt);
    case 0x08: return cb_rrc(fd, tgt);
    case 0x10: return cb_rl(fd, tgt);
    case 0x18: return cb_rr(fd, tgt);
    case 0x20: return cb_sla(fd, tgt);
    case 0x28: return cb_sra(fd, tgt);
  }

  return "???";
}

op_result op_cb(fundude* fd, uint8_t op) {
  uint8_t* tgt = cb_tgt(fd, op);
  if (tgt) {
    char* op_name = cb_run(fd, op, tgt);
    return OP_STEP(fd, 2, 8, "%s %s", op_name, db_reg8(fd, (void*)tgt));
  } else {
    tgt = fdm_ptr(&fd->mem, fd->reg.HL._);
    char* op_name = cb_run(fd, op, tgt);
    return OP_STEP(fd, 2, 16, "%s (HL)", op_name);
  }
}
