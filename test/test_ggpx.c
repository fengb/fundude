#include <stddef.h>
#include "ggpx.h"
#include "tap_eq.h"

int main() {
  plan(8);

  ggp_input in = GGP_INPUT_A | GGP_INPUT_SELECT | GGP_INPUT_UP | GGP_INPUT_LEFT;

  ggp_io dpad = ggp_dpad(in);
  ok(dpad.P10 == 1);  // 1 = open, 0 = pressed (...)
  ok(dpad.P11 == 0);
  ok(dpad.P12 == 0);
  ok(dpad.P13 == 1);

  ggp_io buttons = ggp_buttons(in);
  ok(buttons.P10 == 0);
  ok(buttons.P11 == 1);
  ok(buttons.P12 == 0);
  ok(buttons.P13 == 1);

  done_testing();
}
