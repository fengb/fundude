#include "intrx.h"

#define OP_CALL 0xCD

static uint8_t intr_addr(fundude* fd) {
  intr_flags cmp = {.raw = fd->mmu.io_ports.IF.raw & fd->mmu.interrupt_enable.raw};
  if (!cmp.raw) {
    return 0;
  }

  if (cmp.vblank) {
    fd->mmu.io_ports.IF.vblank = false;
    return 0x40;
  } else if (cmp.lcd_stat) {
    fd->mmu.io_ports.IF.lcd_stat = false;
    return 0x48;
  } else if (cmp.timer) {
    fd->mmu.io_ports.IF.timer = false;
    return 0x50;
  } else if (cmp.serial) {
    fd->mmu.io_ports.IF.serial = false;
    return 0x58;
  } else if (cmp.joypad) {
    fd->mmu.io_ports.IF.joypad = false;
    return 0x60;
  }

  return 0;
}

cpu_result intr_step(fundude* fd) {
  static uint8_t synth_op[3] = {OP_CALL, 0, 0};

  if (!fd->interrupt_master) {
    return (cpu_result){0, 0, 0, 0};
  }

  synth_op[1] = intr_addr(fd);
  if (!synth_op[1]) {
    return (cpu_result){0, 0, 0, 0};
  }

  fd->interrupt_master = false;
  // TODO: this is silly -- we reverse the hacked offset in OP CALL
  fd->cpu.PC._ -= 3;
  return cpu_step(fd, synth_op);
}
