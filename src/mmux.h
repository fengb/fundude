#include <stdint.h>
#include "fundude.h"

extern uint8_t BOOTLOADER[0x100];

#define BEYOND_BOOTLOADER 0x100
#define BEYOND_CART 0x8000

uint8_t* mmu_ptr(mmu* m, uint16_t addr);
uint8_t mmu_get(mmu* m, uint16_t addr);
void mmu_set(fundude* fd, uint16_t addr, uint8_t val);
