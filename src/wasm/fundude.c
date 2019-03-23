#include <stdlib.h>
#include <string.h>
#include "fundude.h"

uint8_t* fd_init() {
  fundude* f = malloc(sizeof(fundude));
  memset(f->display, 0, sizeof(f->display));
  return f->display;
}
