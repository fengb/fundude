#include "registers.h"
#include "tap_eq.h"

int main() {
  plan(4);

  fd_registers reg;

  reg.A._ = 0x12;
  reg.F._ = 0x34;
  eqhex(reg.AF._, 0x1234);

  reg.B._ = 0x23;
  reg.C._ = 0x34;
  eqhex(reg.BC._, 0x2334);

  reg.D._ = 0x58;
  reg.E._ = 0x76;
  eqhex(reg.DE._, 0x5876);

  reg.H._ = 0xAF;
  reg.L._ = 0xCD;
  eqhex(reg.HL._, 0xAFCD);

  done_testing();
}
