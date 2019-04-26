// Shim for libc -- wasm doesn't have standard headers

#include <stddef.h>

void* malloc(size_t);
void free(void*);
void* memset(void*, int, size_t);
