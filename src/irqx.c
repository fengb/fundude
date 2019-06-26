#include "irqx.h"

#define OP_CALL 0xCD

typedef union {
  uint8_t _;
  struct {
    bool vblank : 1;
    bool lcd_stat : 1;
    bool timer : 1;
    bool serial : 1;
    bool joypad : 1;
  };
} HACK_FLAGS;

static uint8_t irq_addr(fundude* fd) {
  HACK_FLAGS cmp = {._ = fd->mmu.io.IF._ & fd->mmu.interrupt_enable._};
  HACK_FLAGS* write = (HACK_FLAGS*)&fd->mmu.io.IF;
  if (!cmp._) {
    return 0;
  }

  if (cmp.vblank) {
    write->vblank = false;
    return 0x40;
  } else if (cmp.lcd_stat) {
    write->lcd_stat = false;
    return 0x48;
  } else if (cmp.timer) {
    write->timer = false;
    return 0x50;
  } else if (cmp.serial) {
    write->serial = false;
    return 0x58;
  } else if (cmp.joypad) {
    write->joypad = false;
    return 0x60;
  }

  return 0;
}

cpu_result irq_step(fundude* fd) {
  if (!fd->interrupt_master) {
    return (cpu_result){0, 0, 0, 0};
  }

  uint8_t addr = irq_addr(fd);
  if (!addr) {
    return (cpu_result){0, 0, 0, 0};
  }

  uint8_t synth_op[3] = {OP_CALL, addr, 0};

  fd->interrupt_master = false;
  // TODO: this is silly -- we reverse the hacked offset in OP CALL
  fd->cpu.PC._ -= 3;
  return cpu_step(fd, synth_op);
}
