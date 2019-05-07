#include "cpux_cb.h"
#include "bit.h"
#include "cpux_do.h"

cb_result cb_rlc(fundude* fd, uint8_t val) {
  return (cb_result){"RLC", do_rlc(fd, val)};
}

cb_result cb_rrc(fundude* fd, uint8_t val) {
  return (cb_result){"RRC", do_rrc(fd, val)};
}

cb_result cb_rl(fundude* fd, uint8_t val) {
  return (cb_result){"RL", do_rl(fd, val)};
}

cb_result cb_rr(fundude* fd, uint8_t val) {
  return (cb_result){"RR", do_rr(fd, val)};
}

cb_result cb_sla(fundude* fd, uint8_t val) {
  return (cb_result){"SLA", flag_shift(fd, val << 1, val >> 7)};
}

cb_result cb_sra(fundude* fd, uint8_t val) {
  uint8_t msb = BIT_GET(val, 7);
  return (cb_result){"SRA", flag_shift(fd, msb | val >> 1, val & 1)};
}

cb_result cb_swap(fundude* fd, uint8_t val) {
  int hi = NIBBLE_HI(val);
  int lo = NIBBLE_LO(val);
  return (cb_result){"SWAP", flag_shift(fd, lo << 4 | hi, false)};
}

cb_result cb_srl(fundude* fd, uint8_t val) {
  return (cb_result){"SRL", flag_shift(fd, val >> 1, val & 1)};
}

#define NAME_GLUE(prefix, var)          \
  const char* name;                     \
  switch (var) {                        \
    case 0: name = prefix " 0"; break;  \
    case 1: name = prefix " 1"; break;  \
    case 2: name = prefix " 2"; break;  \
    case 3: name = prefix " 3"; break;  \
    case 4: name = prefix " 4"; break;  \
    case 5: name = prefix " 5"; break;  \
    case 6: name = prefix " 6"; break;  \
    case 7: name = prefix " 7"; break;  \
    default: name = prefix " ?"; break; \
  }

cb_result cb_bit(fundude* fd, uint8_t val, int bit) {
  fd->cpu.FLAGS = (cpu_flags){
      .Z = BIT_GET(val, bit) == 0,
      .N = false,
      .H = true,
      .C = fd->cpu.FLAGS.C,
  };
  NAME_GLUE("BIT", bit);
  return (cb_result){name, val};
}

cb_result cb_res(fundude* fd, uint8_t val, int bit) {
  uint8_t mask = ~(1 << bit);
  NAME_GLUE("RES", bit);
  return (cb_result){name, val & mask};
}

cb_result cb_set(fundude* fd, uint8_t val, int bit) {
  uint8_t mask = 1 << bit;
  NAME_GLUE("SET", bit);
  return (cb_result){name, val | mask};
}

cpu_reg8* cb_tgt(fundude* fd, uint8_t op) {
  switch (op & 7) {
    case 0: return &fd->cpu.B;
    case 1: return &fd->cpu.C;
    case 2: return &fd->cpu.D;
    case 3: return &fd->cpu.E;
    case 4: return &fd->cpu.H;
    case 5: return &fd->cpu.L;
    case 6: return NULL;
    case 7: return &fd->cpu.A;
  }

  return NULL;
}

cb_result cb_run(fundude* fd, uint8_t op, uint8_t val) {
  switch (op & 0xF8) {
    case 0x00: return cb_rlc(fd, val);
    case 0x08: return cb_rrc(fd, val);
    case 0x10: return cb_rl(fd, val);
    case 0x18: return cb_rr(fd, val);
    case 0x20: return cb_sla(fd, val);
    case 0x28: return cb_sra(fd, val);
    case 0x30: return cb_swap(fd, val);
    case 0x38: return cb_srl(fd, val);

    case 0x40: return cb_bit(fd, val, 0);
    case 0x48: return cb_bit(fd, val, 1);
    case 0x50: return cb_bit(fd, val, 2);
    case 0x58: return cb_bit(fd, val, 3);
    case 0x60: return cb_bit(fd, val, 4);
    case 0x68: return cb_bit(fd, val, 5);
    case 0x70: return cb_bit(fd, val, 6);
    case 0x78: return cb_bit(fd, val, 7);

    case 0x80: return cb_res(fd, val, 0);
    case 0x88: return cb_res(fd, val, 1);
    case 0x90: return cb_res(fd, val, 2);
    case 0x98: return cb_res(fd, val, 3);
    case 0xA0: return cb_res(fd, val, 4);
    case 0xA8: return cb_res(fd, val, 5);
    case 0xB0: return cb_res(fd, val, 6);
    case 0xB8: return cb_res(fd, val, 7);

    case 0xC0: return cb_set(fd, val, 0);
    case 0xC8: return cb_set(fd, val, 1);
    case 0xD0: return cb_set(fd, val, 2);
    case 0xD8: return cb_set(fd, val, 3);
    case 0xE0: return cb_set(fd, val, 4);
    case 0xE8: return cb_set(fd, val, 5);
    case 0xF0: return cb_set(fd, val, 6);
    case 0xF8: return cb_set(fd, val, 7);
  }

  return (cb_result){"???", 0};
}
