#ifndef __IRQ_H
#define __IRQ_H

typedef union {
  uint8_t raw;
  struct {
    bool vblank : 1;
    bool lcd_stat : 1;
    bool timer : 1;
    bool serial : 1;
    bool joypad : 1;
  };
} irq_flags;

#endif
