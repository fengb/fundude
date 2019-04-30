#ifndef __INTR_H
#define __INTR_H

typedef struct {
  bool vblank : 1;
  bool lcd_stat : 1;
  bool timer : 1;
  bool serial : 1;
  bool joypad : 1;
} intr_flags;

#endif
