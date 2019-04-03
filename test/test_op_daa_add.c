#include <stdint.h>
#include "op.h"
#include "tap_eq.h"

#define OP_DAA 0x27
#define OP_ADD_A 0xC6

int main() {
  plan(9);

  fundude fd;

  fd.reg.A._ = 0x00;

  op_tick(&fd, (uint8_t[]){OP_ADD_A, 0x05});
  eqhex(fd.reg.A._, 0x05);
  op_tick(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.reg.A._, 0x05);

  op_tick(&fd, (uint8_t[]){OP_ADD_A, 0x09});
  eqhex(fd.reg.A._, 0x0E);
  op_tick(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.reg.A._, 0x14);
  eqbool(fd.reg.FLAGS.C, false);

  op_tick(&fd, (uint8_t[]){OP_ADD_A, 0x91});
  eqhex(fd.reg.A._, 0xA5);
  eqbool(fd.reg.FLAGS.C, false);
  op_tick(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.reg.A._, 0x05);
  eqbool(fd.reg.FLAGS.C, true);

  done_testing();
}
