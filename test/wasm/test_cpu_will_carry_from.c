#include "tap.c"
#include "cpu.h"

int main() {
  plan(12);

  ok(will_carry_from(0, 0b1, 0b1));
  ok(will_carry_from(1, 0b10, 0b10));
  ok(will_carry_from(1, 0b11111111, 0b00000001));
  ok(will_carry_from(5, 0b11111111, 0b00000001));
  ok(will_carry_from(7, 0b11111111, 0b00000001));

  ok(!will_carry_from(0, 0b0, 0b0));
  ok(!will_carry_from(0, 0b0, 0b1));
  ok(!will_carry_from(0, 0b1, 0b0));
  ok(!will_carry_from(0, 0b10, 0b10));
  ok(!will_carry_from(0, 0b11111011, 0b00000100));
  ok(!will_carry_from(5, 0b11111011, 0b00000100));
  ok(!will_carry_from(7, 0b11111011, 0b00000100));

  done_testing();
}
