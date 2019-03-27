#include "registers.h"
#include "tap.c"

int main() {
  plan(3);

  fd_registers reg;

  reg.FLAGS = (fd_flags){
      .Z = true,
      .N = true,
      .H = true,
      .C = true,
  };
  ok(reg.F._ == 0xF0, "0xF0 == 0x%x", reg.F._);

  reg.FLAGS = (fd_flags){
      .Z = true,
      .N = false,
      .H = false,
      .C = false,
  };
  ok(reg.F._ == 0b10000000, "0x80 == 0x%x", reg.F._);

  reg.FLAGS = (fd_flags){
      .Z = false,
      .N = false,
      .H = false,
      .C = true,
  };
  ok(reg.F._ == 0b00010000, "0x10 == 0x%x", reg.F._);

  done_testing();
}
