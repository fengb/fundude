#include "registers.h"
#include "tap_eq.h"

int main() {
  plan(3);

  fd_registers reg;

  reg.FLAGS = (fd_flags){
      .Z = true,
      .N = true,
      .H = true,
      .C = true,
  };
  eqhex(reg.F._, 0xF0);

  reg.FLAGS = (fd_flags){
      .Z = true,
      .N = false,
      .H = false,
      .C = false,
  };
  eqhex(reg.F._, 0b10000000);

  reg.FLAGS = (fd_flags){
      .Z = false,
      .N = false,
      .H = false,
      .C = true,
  };
  eqhex(reg.F._, 0b00010000);

  done_testing();
}
