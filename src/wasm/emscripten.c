#include <emscripten.h>
#include "fundude.h"

EMSCRIPTEN_KEEPALIVE
uint8_t* init(void) {
  return fd_init();
}

EMSCRIPTEN_KEEPALIVE
int main() {
  return 0;
}
