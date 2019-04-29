#include "cpu.h"
#include "tap_eq.h"

int main() {
  plan(4);

  cpu cpu;

  cpu.A._ = 0x12;
  cpu.F._ = 0x34;
  eqhex(cpu.AF._, 0x1234);

  cpu.B._ = 0x23;
  cpu.C._ = 0x34;
  eqhex(cpu.BC._, 0x2334);

  cpu.D._ = 0x58;
  cpu.E._ = 0x76;
  eqhex(cpu.DE._, 0x5876);

  cpu.H._ = 0xAF;
  cpu.L._ = 0xCD;
  eqhex(cpu.HL._, 0xAFCD);

  done_testing();
}
