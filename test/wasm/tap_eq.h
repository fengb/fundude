#include "tap.c"

#define eqhex(a, b) ok((a) == (b), "0x%X == 0x%X", (a), (b))
#define eqchar(a, b) ok((a) == (b), "'%c' == '%c'", (a), (b))
#define eqbool(a, b) ok((a) == (b), "%s == %s", (a) ? "true" : "false", (b) ? "true" : "false")
