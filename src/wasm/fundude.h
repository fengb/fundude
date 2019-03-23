#include <stdint.h>

#define WIDTH 160
#define HEIGHT 144

typedef struct {
  uint8_t display[WIDTH * HEIGHT];
} fundude;

uint8_t* fd_init(void);
