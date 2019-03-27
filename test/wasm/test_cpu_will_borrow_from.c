#include "tap.c"
#include "cpu.h"

int main() {
  plan(9);

  ok(will_borrow_from(1, 0b0, 0b1));
  ok(will_borrow_from(5, 0b0, 0b1));
  ok(will_borrow_from(7, 0b0, 0b1));
  ok(will_borrow_from(2, 0b100, 0b10));

  ok(!will_borrow_from(0, 0b0, 0b0));
  ok(!will_borrow_from(0, 0b1, 0b0));
  ok(!will_borrow_from(0, 0b10, 0b10));
  ok(!will_borrow_from(0, 0b10, 0b11));
  ok(!will_borrow_from(1, 0b00, 0b10));

  done_testing();
}
