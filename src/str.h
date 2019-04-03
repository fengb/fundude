#ifndef __STR_H
#define __STR_H

// This lets us allocate on the stack
typedef struct {
  char _[64];
} str;

#endif
