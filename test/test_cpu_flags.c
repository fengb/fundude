#include "cpu.h"
#include "tap_eq.h"

int main() {
  plan(3);

  cpu cpu;

  cpu.FLAGS = (cpu_flags){
      .Z = true,
      .N = true,
      .H = true,
      .C = true,
  };
  eqhex(cpu.F._, 0xF0);

  cpu.FLAGS = (cpu_flags){
      .Z = true,
      .N = false,
      .H = false,
      .C = false,
  };
  eqhex(cpu.F._, 0b10000000);

  cpu.FLAGS = (cpu_flags){
      .Z = false,
      .N = false,
      .H = false,
      .C = true,
  };
  eqhex(cpu.F._, 0b00010000);

  done_testing();
}
