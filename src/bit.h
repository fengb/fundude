#include <stdint.h>

#define BIT_GET(data, i) (((data) >> (i)) & 1)
#define NIBBLE_GET(data, i) (((data) >> (i * 4)) & 0xF)
#define BYTE_GET(data, i) (((data) >> (i * 8)) & 0xFF)

#define NIBBLE_HI(data) ((data >> 4) & 0xF)
#define NIBBLE_LO(data) ((data >> 0) & 0xF)

#define BYTE_HI(data) ((data >> 8) & 0xFF)
#define BYTE_LO(data) ((data >> 0) & 0xFF)
