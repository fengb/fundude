#include <stdbool.h>
#include <stdint.h>

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
    uint8_t SB;
    uint8_t SC;
    uint8_t _pad_ff04;
    uint8_t DIV;
    uint8_t TIMA;
    uint8_t TMA;
    uint8_t TAC;
    uint8_t _pad_ff07_ef[7];
    uint8_t IF;

    uint8_t NR10;
    uint8_t NR11;
    uint8_t NR12;
    uint8_t NR13;
    uint8_t NR14;
    uint8_t NR21;
    uint8_t NR22;
    uint8_t NR23;
    uint8_t NR24;
    uint8_t _pad_ff1a;
    uint8_t NR30;
    uint8_t NR31;
    uint8_t NR32;
    uint8_t NR33;
    uint8_t NR34;
    uint8_t _pad_ff1f;

    uint8_t NR41;
    uint8_t NR42;
    uint8_t NR43;
    uint8_t NR44;
    uint8_t NR50;
    uint8_t NR51;
    uint8_t NR52;
    uint8_t _pad_ff27_2f[9];

    uint8_t wave_pattern[0x10];

    uint8_t LCDC;
    uint8_t STAT;
    uint8_t SCY;
    uint8_t SCX;
    uint8_t LY;
    uint8_t LYC;
    uint8_t DMA;
    uint8_t BGP;
    uint8_t OBP0;
    uint8_t OBP1;
    uint8_t WY;
    uint8_t WX;
  };
} fd_io;
