#include "registers.h"
#include "tap.c"

int main() {
  plan(8);

  fd_registers reg;

  reg.A._ = 0xF7;
  reg.F._ = 0x00;
  ok(reg.AF._ == 0xF700, "0xF700 == 0x%x", reg.AF._);

  reg.A._ = 0x00;
  reg.F._ = 0xF7;
  ok(reg.AF._ == 0x00F7, "0x00F7 == 0x%x", reg.AF._);

  reg.B._ = 0xF7;
  reg.C._ = 0x00;
  ok(reg.BC._ == 0xF700, "0xF700 == 0x%x", reg.BC._);

  reg.B._ = 0x00;
  reg.C._ = 0xF7;
  ok(reg.BC._ == 0x00F7, "0x00F7 == 0x%x", reg.BC._);

  reg.D._ = 0xF7;
  reg.E._ = 0x00;
  ok(reg.DE._ == 0xF700, "0xF700 == 0x%x", reg.DE._);

  reg.D._ = 0x00;
  reg.E._ = 0xF7;
  ok(reg.DE._ == 0x00F7, "0x00F7 == 0x%x", reg.DE._);

  reg.H._ = 0xF7;
  reg.L._ = 0x00;
  ok(reg.HL._ == 0xF700, "0xF700 == 0x%x", reg.HL._);

  reg.H._ = 0x00;
  reg.L._ = 0xF7;
  ok(reg.HL._ == 0x00F7, "0x00F7 == 0x%x", reg.HL._);

  done_testing();
}
