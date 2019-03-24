#include <stdlib.h>
#include <string.h>
#include "fundude.h"

fundude* fd_init() {
  fundude* fd = malloc(sizeof(fundude));
  memset(fd->display, 0, sizeof(fd->display));
  return fd;
}
