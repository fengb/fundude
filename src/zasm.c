#include "zasm.h"
#include <stdio.h>
#include <string.h>

zasm zasm0(const char* name) {
  return (zasm){name, 0, 0};
}

zasm zasm1(const char* name, zasm_arg arg) {
  return (zasm){name, arg, 0};
}

zasm zasm2(const char* name, zasm_arg arg1, zasm_arg arg2) {
  return (zasm){name, arg1, arg2};
}

zasm_arg zasma_cond(cond c) {
  return (zasm_arg){ZASM_COND, ZASM_PLAIN, c};
}

zasm_arg zasma_sys_mode(sys_mode m) {
  return (zasm_arg){ZASM_SYS_MODE, ZASM_PLAIN, m};
}

zasm_arg zasma_reg8(zasm_format f, fundude* fd, reg8* reg) {
  uint16_t offset = (void*)reg - (void*)&fd->reg;
  return (zasm_arg){ZASM_REG8, f, offset};
}

zasm_arg zasma_reg16(zasm_format f, fundude* fd, reg16* reg) {
  uint16_t offset = (void*)reg - (void*)&fd->reg;
  return (zasm_arg){ZASM_REG16, f, offset};
}

zasm_arg zasma_hex8(zasm_format f, uint8_t val) {
  return (zasm_arg){ZASM_HEX8, f, val};
}

zasm_arg zasma_hex16(zasm_format f, uint16_t val) {
  return (zasm_arg){ZASM_HEX16, f, val};
}

static char* zasma_raw(zasm_arg arg) {
  static char buf[8];
  switch (arg.type) {
    case ZASM_COND:
      switch (arg.val) {
        case COND_NZ: return "NZ";
        case COND_Z: return "Z";
        case COND_NC: return "NC";
        case COND_C: return "C";
        default: return "N?";
      }
    case ZASM_SYS_MODE:
      switch (arg.type) {
        case SYS_NORM: return "NORM";
        case SYS_HALT: return "HALT";
        case SYS_STOP: return "STOP";
        case SYS_FATAL: return "FATAL";
        default: return "MODE?";
      }
    case ZASM_REG8:
      switch (arg.val) {
        case offsetof(fd_registers, A): return "A";
        case offsetof(fd_registers, F): return "F";
        case offsetof(fd_registers, B): return "B";
        case offsetof(fd_registers, C): return "C";
        case offsetof(fd_registers, D): return "D";
        case offsetof(fd_registers, E): return "E";
        case offsetof(fd_registers, H): return "H";
        case offsetof(fd_registers, L): return "L";
        default: return "R?";
      }
    case ZASM_REG16:
      switch (arg.val) {
        case offsetof(fd_registers, AF): return "AF";
        case offsetof(fd_registers, BC): return "BC";
        case offsetof(fd_registers, DE): return "DE";
        case offsetof(fd_registers, HL): return "HL";
        case offsetof(fd_registers, SP): return "SP";
        case offsetof(fd_registers, PC): return "PC";
        default: return "W?";
      }
    case ZASM_HEX8: snprintf(buf, sizeof(buf), "$%02X", arg.val); return buf;
    case ZASM_HEX16: snprintf(buf, sizeof(buf), "$%04X", arg.val); return buf;
    default: return 0;
  }
}

static char* zasma_str(zasm_arg arg) {
  static char buf[16];
  char* raw = zasma_raw(arg);
  if (raw == 0) {
    return "";
  }
  switch (arg.format) {
    case ZASM_PLAIN: snprintf(buf, sizeof(buf), " %s", raw); return buf;
    case ZASM_PAREN: snprintf(buf, sizeof(buf), " (%s)", raw); return buf;
    case ZASM_HIMEM: snprintf(buf, sizeof(buf), " ($FF00+%s)", raw); return buf;
  }
  return " ???";
}

int zasm_snprintf(char* out, size_t size, zasm z) {
  strncpy(out, z.name, size);
  strncat(out, zasma_str(z.arg1), size);
  strncat(out, zasma_str(z.arg2), size);
  return size;
}
