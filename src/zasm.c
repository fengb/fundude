#include "zasm.h"

zasm zasm0(const char* name) {
  return (zasm){name, 0, 0};
}

zasm zasm1(const char* name, zasm_arg arg) {
  return (zasm){name, arg, 0};
}

zasm zasm2(const char* name, zasm_arg arg1, zasm_arg arg2) {
  return (zasm){name, arg1, arg2};
}

zasm_arg zasma_cond(cpu_cond c) {
  return (zasm_arg){ZASM_COND, ZASM_PLAIN, c};
}

zasm_arg zasma_sys_mode(sys_mode m) {
  return (zasm_arg){ZASM_SYS_MODE, ZASM_PLAIN, m};
}

zasm_arg zasma_reg8(zasm_format f, fundude* fd, cpu_reg8* reg) {
  uint16_t offset = (void*)reg - (void*)&fd->cpu;
  return (zasm_arg){ZASM_REG8, f, offset};
}

zasm_arg zasma_reg16(zasm_format f, fundude* fd, cpu_reg16* reg) {
  uint16_t offset = (void*)reg - (void*)&fd->cpu;
  return (zasm_arg){ZASM_REG16, f, offset};
}

zasm_arg zasma_hex8(zasm_format f, uint8_t val) {
  return (zasm_arg){ZASM_HEX8, f, val};
}

zasm_arg zasma_hex16(zasm_format f, uint16_t val) {
  return (zasm_arg){ZASM_HEX16, f, val};
}

static char hexch(int i, int byte_offset) {
  switch ((i >> (byte_offset * 8)) & 0xF) {
    case 0x0: return '0';
    case 0x1: return '1';
    case 0x2: return '2';
    case 0x3: return '3';
    case 0x4: return '4';
    case 0x5: return '5';
    case 0x6: return '6';
    case 0x7: return '7';
    case 0x8: return '8';
    case 0x9: return '9';
    case 0xA: return 'A';
    case 0xB: return 'B';
    case 0xC: return 'C';
    case 0xD: return 'D';
    case 0xE: return 'E';
    case 0xF: return 'F';
    default: return '?';
  }
}

static size_t putsn(char* out, size_t limit, const char* in) {
  size_t i;
  for (i = 0; i < limit; i++) {
    out[i] = in[i];

    if (in[i] == '\0') {
      break;
    }
  }

  return i;
}

static char* zasma_raw(zasm_arg arg) {
  switch (arg.type) {
    case ZASM_COND:
      switch (arg.val) {
        case CPU_COND_NZ: return "NZ";
        case CPU_COND_Z: return "Z";
        case CPU_COND_NC: return "NC";
        case CPU_COND_C: return "C";
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
        case offsetof(cpu, A): return "A";
        case offsetof(cpu, F): return "F";
        case offsetof(cpu, B): return "B";
        case offsetof(cpu, C): return "C";
        case offsetof(cpu, D): return "D";
        case offsetof(cpu, E): return "E";
        case offsetof(cpu, H): return "H";
        case offsetof(cpu, L): return "L";
        default: return "R?";
      }
    case ZASM_REG16:
      switch (arg.val) {
        case offsetof(cpu, AF): return "AF";
        case offsetof(cpu, BC): return "BC";
        case offsetof(cpu, DE): return "DE";
        case offsetof(cpu, HL): return "HL";
        case offsetof(cpu, SP): return "SP";
        case offsetof(cpu, PC): return "PC";
        default: return "W?";
      }
    case ZASM_HEX8: {
      static char buf[4];
      buf[0] = '$';
      buf[1] = hexch(arg.val, 1);
      buf[2] = hexch(arg.val, 0);
      buf[3] = '\0';
      return buf;
    }
    case ZASM_HEX16: {
      static char buf[6];
      buf[0] = '$';
      buf[1] = hexch(arg.val, 3);
      buf[2] = hexch(arg.val, 2);
      buf[3] = hexch(arg.val, 1);
      buf[4] = hexch(arg.val, 0);
      buf[5] = '\0';
      return buf;
    }
    default: return 0;
  }
}

static size_t zasma_puts(char* out, size_t limit, zasm_arg arg) {
  char* raw = zasma_raw(arg);
  if (raw == 0) {
    return 0;
  }

  size_t offset = 0;
  switch (arg.format) {
    case ZASM_PLAIN:
      offset += putsn(out + offset, limit - offset, " ");
      offset += putsn(out + offset, limit - offset, raw);
      return offset;
    case ZASM_PAREN:
      offset += putsn(out + offset, limit - offset, " (");
      offset += putsn(out + offset, limit - offset, raw);
      offset += putsn(out + offset, limit - offset, ")");
      return offset;
    case ZASM_HIMEM:
      offset += putsn(out + offset, limit - offset, " ($FF00+");
      offset += putsn(out + offset, limit - offset, raw);
      offset += putsn(out + offset, limit - offset, ")");
      return offset;
    default:  //
      offset += putsn(out + offset, limit - offset, " ???");
      offset += putsn(out + offset, limit - offset, raw);
      return offset;
  }
}

int zasm_puts(char* out, size_t limit, zasm z) {
  size_t offset = 0;
  offset += putsn(out + offset, limit - offset, z.name);
  offset += zasma_puts(out + offset, limit - offset, z.arg1);
  offset += zasma_puts(out + offset, limit - offset, z.arg2);
  return offset;
}
