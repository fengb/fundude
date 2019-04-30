#include <stdbool.h>
#include <stdint.h>
#include "intr.h"

typedef enum __attribute__((__packed__)) {
  SHADE_WHITE = 0,
  SHADE_LIGHT_GRAY = 1,
  SHADE_DARK_GRAY = 2,
  SHADE_BLACK = 3,
} shade;

typedef enum __attribute__((__packed__)) {
  LCDC_HBLANK = 0,
  LCDC_VBLANK = 1,
  LCDC_SEARCHING = 2,
  LCDC_TRANSFERRING = 3,
} lcdc_mode;

typedef struct __attribute__((__packed__)) {
  shade color0 : 2;
  shade color1 : 2;
  shade color2 : 2;
  shade color3 : 2;
} color_palette;

typedef enum __attribute__((__packed__)) {
  IO_TIMER_SPEED_4096 = 0,
  IO_TIMER_SPEED_262144 = 1,
  IO_TIMER_SPEED_65536 = 2,
  IO_TIMER_SPEED_16384 = 3,
} io_timer_speed;

typedef union {
  uint8_t RAW[0x4C];
  struct {
    union {
      uint8_t _;
      struct {
        bool P10 : 1;
        bool P11 : 1;
        bool P12 : 1;
        bool P13 : 1;
        bool P14 : 1;
        bool P15 : 1;
        uint8_t _padding : 2;
      };
    } P1;
    uint8_t SB;  // $FF01
    uint8_t SC;  // $FF02
    uint8_t _pad_ff03;
    uint8_t DIV;   // $FF04
    uint8_t TIMA;  // $FF05
    uint8_t TMA;   // $FF06
    struct {
      io_timer_speed speed : 2;
      bool active : 1;
    } TAC;
    uint8_t _pad_ff08_0e[7];
    intr_flags IF;  // FF0F

    uint8_t NR10;  // $FF10
    uint8_t NR11;  // $FF11
    uint8_t NR12;  // $FF12
    uint8_t NR13;  // $FF13
    uint8_t NR14;  // $FF14
    uint8_t NR21;  // $FF15
    uint8_t NR22;  // $FF16
    uint8_t NR23;  // $FF17
    uint8_t NR24;  // $FF18
    uint8_t _pad_ff1a;
    uint8_t NR30;  // $FF1A
    uint8_t NR31;  // $FF1B
    uint8_t NR32;  // $FF1C
    uint8_t NR33;  // $FF1D
    uint8_t NR34;  // $FF1E
    uint8_t _pad_ff1f;

    uint8_t NR41;  // $FF20
    uint8_t NR42;  // $FF21
    uint8_t NR43;  // $FF22
    uint8_t NR44;  // $FF23
    uint8_t NR50;  // $FF24
    uint8_t NR51;  // $FF25
    uint8_t NR52;  // $FF26
    uint8_t _pad_ff27_2f[9];

    uint8_t wave_pattern[0x10];  // $FF30 - FF3F

    struct {
      bool bg_enable : 1;
      bool obj_enable : 1;
      uint8_t obj_size : 1;
      uint8_t bg_tile_map : 1;
      uint8_t bg_window_tile_data : 1;
      bool window_enable : 1;
      uint8_t window_tile_map : 1;
      bool lcd_enable : 1;
    } LCDC;
    struct {
      lcdc_mode mode : 2;
      bool coincidence : 1;
      bool hblank_int : 1;
      bool vblank_int : 1;
      bool oam_int : 1;
      bool coincidence_int : 1;
    } STAT;
    uint8_t SCY;         // $FF42
    uint8_t SCX;         // $FF43
    uint8_t LY;          // $FF44
    uint8_t LYC;         // $FF45
    uint8_t DMA;         // $FF46
    color_palette BGP;   // $FF47
    color_palette OBP0;  // $FF48
    color_palette OBP1;  // $FF49
    uint8_t WY;          // $FF4A
    uint8_t WX;          // $FF4B
  };
} io;
