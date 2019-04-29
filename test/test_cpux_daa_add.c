#include <stdint.h>
#include "cpux.h"
#include "tap_eq.h"

#define OP_DAA 0x27
#define OP_ADD_A 0xC6

int main() {
  plan(9);

  fundude fd;

  fd.cpu.A._ = 0x00;

  cpu_tick(&fd, (uint8_t[]){OP_ADD_A, 0x05});
  eqhex(fd.cpu.A._, 0x05);
  cpu_tick(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.cpu.A._, 0x05);

  cpu_tick(&fd, (uint8_t[]){OP_ADD_A, 0x09});
  eqhex(fd.cpu.A._, 0x0E);
  cpu_tick(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.cpu.A._, 0x14);
  eqbool(fd.cpu.FLAGS.C, false);

  cpu_tick(&fd, (uint8_t[]){OP_ADD_A, 0x91});
  eqhex(fd.cpu.A._, 0xA5);
  eqbool(fd.cpu.FLAGS.C, false);
  cpu_tick(&fd, (uint8_t[]){OP_DAA});
  eqhex(fd.cpu.A._, 0x05);
  eqbool(fd.cpu.FLAGS.C, true);

  done_testing();
}
