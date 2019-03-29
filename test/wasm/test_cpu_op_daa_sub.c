#include <stdint.h>
#include "cpu.h"
#include "tap_eq.h"

#define OP_DAA 0x27
#define OP_SUB_A 0xD6

int main() {
  plan(9);

  fundude fd;

  fd.reg.A._ = 0x45;

  fd_run(&fd, (uint8_t[]){OP_SUB_A, 0x02});
  eqhex(fd.reg.A._, 0x43);
  fd_run(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.reg.A._, 0x43);

  fd_run(&fd, (uint8_t[]){OP_SUB_A, 0x05});
  eqhex(fd.reg.A._, 0x3E);
  fd_run(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.reg.A._, 0x38);
  eqbool(fd.reg.FLAGS.C, false);

  fd_run(&fd, (uint8_t[]){OP_SUB_A, 0x91});
  eqhex(fd.reg.A._, 0xA7);
  eqbool(fd.reg.FLAGS.C, true);
  fd_run(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.reg.A._, 0x07);
  eqbool(fd.reg.FLAGS.C, true);

  done_testing();
}
