#include <stdlib.h>
#include <string.h>
#include "fundude.h"

fundude* fd_init(uint32_t us_ref) {
  fundude* fd = malloc(sizeof(fundude));
  memset(fd->display, 0, sizeof(fd->display));
  fd->us = us_ref;
  return fd;
}
