#include "cpu.h"
#include "tap.c"

int main() {
  plan(8);

  cpu cpu;

  cpu.A._ = 0xF7;
  cpu.F._ = 0x00;
  ok(cpu.AF._ == 0xF700, "0xF700 == 0x%x", cpu.AF._);

  cpu.A._ = 0x00;
  cpu.F._ = 0xF7;
  ok(cpu.AF._ == 0x00F7, "0x00F7 == 0x%x", cpu.AF._);

  cpu.B._ = 0xF7;
  cpu.C._ = 0x00;
  ok(cpu.BC._ == 0xF700, "0xF700 == 0x%x", cpu.BC._);

  cpu.B._ = 0x00;
  cpu.C._ = 0xF7;
  ok(cpu.BC._ == 0x00F7, "0x00F7 == 0x%x", cpu.BC._);

  cpu.D._ = 0xF7;
  cpu.E._ = 0x00;
  ok(cpu.DE._ == 0xF700, "0xF700 == 0x%x", cpu.DE._);

  cpu.D._ = 0x00;
  cpu.E._ = 0xF7;
  ok(cpu.DE._ == 0x00F7, "0x00F7 == 0x%x", cpu.DE._);

  cpu.H._ = 0xF7;
  cpu.L._ = 0x00;
  ok(cpu.HL._ == 0xF700, "0xF700 == 0x%x", cpu.HL._);

  cpu.H._ = 0x00;
  cpu.L._ = 0xF7;
  ok(cpu.HL._ == 0x00F7, "0x00F7 == 0x%x", cpu.HL._);

  done_testing();
}
