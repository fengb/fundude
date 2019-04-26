#include <emscripten.h>
#include "fundude.h"

EMSCRIPTEN_KEEPALIVE
fundude* alloc() {
  fundude* fd = fd_alloc();
  return fd;
}

EMSCRIPTEN_KEEPALIVE
void init(fundude* fd, size_t cart_length, uint8_t cart[]) {
  fd_init(fd, cart_length, cart);
}

EMSCRIPTEN_KEEPALIVE
int step(fundude* fd) {
  return fd_step(fd);
}

EMSCRIPTEN_KEEPALIVE
void set_breakpoint(fundude* fd, int breakpoint) {
  fd->breakpoint = breakpoint;
}

EMSCRIPTEN_KEEPALIVE
int step_frames(fundude* fd, short frames) {
  return fd_step_frames(fd, frames);
}

EMSCRIPTEN_KEEPALIVE
char* disassemble(fundude* fd) {
  return fd_disassemble(fd);
}

EMSCRIPTEN_KEEPALIVE
void* background_ptr(fundude* fd) {
  return &fd->background;
}

EMSCRIPTEN_KEEPALIVE
void* window_ptr(fundude* fd) {
  return &fd->window;
}

EMSCRIPTEN_KEEPALIVE
void* tile_data_ptr(fundude* fd) {
  return &fd->tile_data;
}

EMSCRIPTEN_KEEPALIVE
fd_registers* registers_ptr(fundude* fd) {
  return &fd->reg;
}

EMSCRIPTEN_KEEPALIVE
fd_memory* memory_ptr(fundude* fd) {
  return &fd->mem;
}

EMSCRIPTEN_KEEPALIVE
int display_width() {
  return WIDTH;
}

EMSCRIPTEN_KEEPALIVE
int display_height() {
  return HEIGHT;
}

EMSCRIPTEN_KEEPALIVE
int main() {
  return 0;
}
