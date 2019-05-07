#include "tap.c"
#include "cpux_do.h"

int main() {
  plan(13);

  ok(will_carry_into(1, 0b1, 0b1));
  ok(will_carry_into(2, 0b10, 0b10));
  ok(will_carry_into(2, 0xff, 0x1));
  ok(will_carry_into(6, 0xff, 0x1));
  ok(will_carry_into(8, 0xff, 0x1));
  ok(will_carry_into(16, 0xffff, 0x1));

  ok(!will_carry_into(1, 0b0, 0b0));
  ok(!will_carry_into(1, 0b0, 0b1));
  ok(!will_carry_into(1, 0b1, 0b0));
  ok(!will_carry_into(1, 0b10, 0b10));
  ok(!will_carry_into(1, 0b11111011, 0b00000100));
  ok(!will_carry_into(6, 0b11111011, 0b00000100));
  ok(!will_carry_into(8, 0b11111011, 0b00000100));

  done_testing();
}
