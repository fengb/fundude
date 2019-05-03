#ifndef __ARRAY_H
#define __ARRAY_H

#include <stddef.h>
#include <stdint.h>

#define ARRAY_LEN(x) (sizeof(x) / sizeof(x[0]))

typedef struct {
  uint8_t* _;
  size_t width;
  size_t height;
} matrix;

#define MATRIX(array2d) ((matrix){&array2d[0][0], ARRAY_LEN(array2d[0]), ARRAY_LEN(array2d)})

#endif
