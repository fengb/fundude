#include <stdint.h>
#include "cpux.h"
#include "tap_eq.h"

#define OP_DAA 0x27
#define OP_SUB_A 0xD6

int main() {
  plan(9);

  fundude fd;

  fd.cpu.A._ = 0x45;

  cpu_step(&fd, (uint8_t[]){OP_SUB_A, 0x02});
  eqhex(fd.cpu.A._, 0x43);
  cpu_step(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.cpu.A._, 0x43);

  cpu_step(&fd, (uint8_t[]){OP_SUB_A, 0x05});
  eqhex(fd.cpu.A._, 0x3E);
  cpu_step(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.cpu.A._, 0x38);
  eqbool(fd.cpu.FLAGS.C, false);

  cpu_step(&fd, (uint8_t[]){OP_SUB_A, 0x91});
  eqhex(fd.cpu.A._, 0xA7);
  eqbool(fd.cpu.FLAGS.C, true);
  cpu_step(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.cpu.A._, 0x47);
  eqbool(fd.cpu.FLAGS.C, true);

  done_testing();
}
