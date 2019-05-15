#include <stddef.h>
#include "bit.h"
#include "ggpx.h"
#include "tap_eq.h"

int main() {
  plan(8);

  ggp_input in = GGP_INPUT_A | GGP_INPUT_SELECT | GGP_INPUT_UP | GGP_INPUT_LEFT;

  uint8_t dpad = ggp_dpad(in);
  ok(BIT_GET(dpad, 0) == 1);  // 1 = open, 0 = pressed (...)
  ok(BIT_GET(dpad, 1) == 0);
  ok(BIT_GET(dpad, 2) == 0);
  ok(BIT_GET(dpad, 3) == 1);

  uint8_t buttons = ggp_buttons(in);
  ok(BIT_GET(buttons, 0) == 0);
  ok(BIT_GET(buttons, 1) == 1);
  ok(BIT_GET(buttons, 2) == 0);
  ok(BIT_GET(buttons, 3) == 1);

  done_testing();
}
