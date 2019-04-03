#include "op_cb.h"
#include "debug.h"

static bool is_uint8_zero(int val) {
  return (val & 0xFF) == 0;
}

// TODO: refactor cb_rlc/rrc/rl/rc and op_rlc/rrc/rla/rca
op_result cb_rlc(fundude* fd, uint8_t* tgt) {
  int msb = *tgt >> 7 & 1;

  *tgt = *tgt << 1 | msb;
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(*tgt),
      .N = false,
      .H = false,
      .C = msb,
  };
  return OP_STEP(fd, 2, 8, "RLC %s", db_reg8(fd, (void*)tgt));
}

op_result cb_rrc(fundude* fd, uint8_t* tgt) {
  int lsb = *tgt & 1;

  *tgt = *tgt >> 1 | (lsb << 7);
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(*tgt),
      .N = false,
      .H = false,
      .C = lsb,
  };
  return OP_STEP(fd, 2, 8, "RRC %s", db_reg8(fd, (void*)tgt));
}

op_result cb_rl(fundude* fd, uint8_t* tgt) {
  int msb = *tgt >> 7 & 1;

  *tgt = *tgt << 1 | fd->reg.FLAGS.C;
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(*tgt),
      .N = false,
      .H = false,
      .C = msb,
  };
  return OP_STEP(fd, 2, 8, "RL %s", db_reg8(fd, (void*)tgt));
}

op_result cb_rr(fundude* fd, uint8_t* tgt) {
  int lsb = *tgt & 1;

  *tgt = *tgt >> 1 | (fd->reg.FLAGS.C << 7);
  fd->reg.FLAGS = (fd_flags){
      .Z = is_uint8_zero(*tgt),
      .N = false,
      .H = false,
      .C = lsb,
  };
  return OP_STEP(fd, 2, 8, "RR %s", db_reg8(fd, (void*)tgt));
}

uint8_t* cb_tgt(fundude* fd, uint8_t op) {
  switch (op & 7) {
    case 0: return &fd->reg.B._;
    case 1: return &fd->reg.C._;
    case 2: return &fd->reg.D._;
    case 3: return &fd->reg.E._;
    case 4: return &fd->reg.H._;
    case 5: return &fd->reg.L._;
    case 6: return fdm_ptr(&fd->mem, fd->reg.HL._);
    case 7: return &fd->reg.A._;
  }

  return 0;
}

op_result op_cb(fundude* fd, uint8_t op) {
  uint8_t* tgt = cb_tgt(fd, op);
  switch (op & 0xF8) {
    case 0x00: return cb_rlc(fd, tgt);
    case 0x08: return cb_rrc(fd, tgt);
    case 0x10: return cb_rl(fd, tgt);
    case 0x18: return cb_rr(fd, tgt);
  }

  // TODO
  return OP_STEP(fd, 2, 8, "CB");
}
