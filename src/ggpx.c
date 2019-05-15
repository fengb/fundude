#include "ggpx.h"
#include "bit.h"

ggp_io ggp_dpad(ggp_input input) {
  return (ggp_io){._ = (~NIBBLE_LO(input) & 0xF)};
}

ggp_io ggp_buttons(ggp_input input) {
  return (ggp_io){._ = (~NIBBLE_HI(input) & 0xF)};
}
