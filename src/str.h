#ifndef __STR_H
#define __STR_H

// This lets us allocate on the stack
typedef struct {
  // TODO: investigate why char[17]-char[31] crashes
  char _[32];
} str;

#endif
