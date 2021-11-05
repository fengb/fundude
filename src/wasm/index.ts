//@ts-ignore
import WASM from "../../zig-out/lib/fundude.wasm";
import PicoSignal from "./PicoSignal";

Object.assign(window, { WASM });

export type Matrix<T> = T & {
  width: number;
  height: number;
};

class U8Chunk extends Uint8Array {
  constructor(public ptr: number, length: number) {
    super(WASM.memory.buffer, ptr, length);
  }

  //toInt(): bigint {
  //  return BigInt(this.ptr) | (BigInt(this.length) << BigInt(32));
  //}

  // TODO: remove floats
  // JS can't handle i64 yet so we're using f64 for now
  toFloat(): number {
    let buf = new ArrayBuffer(8);
    let u32s = new Uint32Array(buf);
    u32s[0] = this.ptr;
    u32s[1] = this.length;
    return new Float64Array(buf)[0];
  }

  static fromFloat(value: number): U8Chunk {
    let buf = new ArrayBuffer(8);
    new Float64Array(buf)[0] = value;
    let u32s = new Uint32Array(buf);
    return new U8Chunk(u32s[0], u32s[1]);
  }

  static matrix(value: number): Matrix<U8Chunk> {
    let buf = new ArrayBuffer(8);
    new Float64Array(buf)[0] = value;
    let u16s = new Uint16Array(buf);
    const ptr = u16s[0] | (u16s[1] << 16);
    const width = u16s[2];
    const height = u16s[3];
    return Object.assign(new U8Chunk(ptr, width * height), { width, height });
  }
}

class U16Chunk extends Uint16Array {
  constructor(private ptr: number, length: number) {
    super(WASM.memory.buffer, ptr, length);
  }

  //toInt(): bigint {
  //  return BigInt(this.ptr) | (BigInt(this.length) << BigInt(32));
  //}

  // TODO: remove floats
  // JS can't handle i64 yet so we're using f64 for now
  toFloat(): number {
    let buf = new ArrayBuffer(8);
    let u32s = new Uint32Array(buf);
    u32s[0] = this.ptr;
    u32s[1] = this.length;
    return new Float64Array(buf)[0];
  }

  static fromFloat(value: number): U16Chunk {
    let buf = new ArrayBuffer(8);
    new Float64Array(buf)[0] = value;
    let u32s = new Uint32Array(buf);
    return new U16Chunk(u32s[0], u32s[1]);
  }

  static matrix(value: number): Matrix<U16Chunk> {
    let buf = new ArrayBuffer(8);
    new Float64Array(buf)[0] = value;
    let u16s = new Uint16Array(buf);
    const ptr = u16s[0] | (u16s[1] << 16);
    const width = u16s[2];
    const height = u16s[3];
    return Object.assign(new U16Chunk(ptr, width * height), { width, height });
  }
}

export const MMU_OFFSETS = {
  shift: 0x8000,
  segments: [
    { start: 0x8000, end: 0xa000 - 1, name: "vram" },
    { start: 0xc000, end: 0xe000 - 1, name: "ram" },
    { start: 0xfe00, end: 0xfea0 - 1, name: "oam" },
    { start: 0xff00, end: 0xff4c - 1, name: "io" },
    { start: 0xff80, end: 0xffff - 1, name: "himem" },
  ],
};

enum InputBitMapping {
  right = 1,
  left = 2,
  up = 4,
  down = 8,

  a = 16,
  b = 32,
  select = 64,
  start = 128,
}

export type Input = keyof typeof InputBitMapping;

export default class FundudeWasm {
  public changed = new PicoSignal<void>();

  private readonly pointer: number;
  cart: Uint8Array;
  private cartCopyPtr: number;

  constructor(cart: Uint8Array) {
    this.pointer = WASM.fd_create();
    this.load(cart);
  }

  screen() {
    return U16Chunk.matrix(WASM.fd_screen(this.pointer));
  }

  background() {
    return U16Chunk.matrix(WASM.fd_background(this.pointer));
  }

  window() {
    return U16Chunk.matrix(WASM.fd_window(this.pointer));
  }

  sprites() {
    return U16Chunk.matrix(WASM.fd_sprites(this.pointer));
  }

  patterns() {
    return U8Chunk.matrix(WASM.fd_patterns(this.pointer));
  }

  cpu() {
    const raw = U8Chunk.fromFloat(WASM.fd_cpu_reg(this.pointer));
    return Object.assign(raw, {
      AF: () => raw[0] + (raw[1] << 8),
      BC: () => raw[2] + (raw[3] << 8),
      DE: () => raw[4] + (raw[5] << 8),
      HL: () => raw[6] + (raw[7] << 8),
      SP: () => raw[8] + (raw[9] << 8),
      PC: () => raw[10] + (raw[11] << 8),
    });
  }

  mmu() {
    return U8Chunk.fromFloat(WASM.fd_mmu(this.pointer));
  }

  load(cart: Uint8Array) {
    if (this.cartCopyPtr) {
      WASM.free(this.cartCopyPtr);
    }

    this.cart = cart;
    this.cartCopyPtr = WASM.malloc(cart.length);
    const copy = new U8Chunk(this.cartCopyPtr, cart.length);
    copy.set(cart);

    const status = WASM.fd_load(this.pointer, copy.toFloat());
    switch (status) {
      case 0:
        break;
      case 1:
        throw new Error("Cart unsupported");
      case 2:
        throw new Error("Cart size invalid");
      case 3:
        throw new Error("Cart ram size error");
      default:
        throw new Error("Unknown error");
    }

    this.changed.dispatch();
  }

  rewind() {
    WASM.fd_rewind(this.pointer);
    this.changed.dispatch();
  }

  dump() {
    const dumpChunk = U8Chunk.fromFloat(WASM.fd_dump(this.pointer));
    try {
      return Uint8Array.from(dumpChunk);
    } finally {
      WASM.free(dumpChunk.ptr);
    }
  }

  restore(bytes: Uint8Array) {
    const ptr = WASM.malloc(bytes.length);
    if (ptr == 0) {
      throw "WASM out of memory";
    }

    const copy = new U8Chunk(ptr, bytes.length);
    copy.set(bytes);
    try {
      const result = WASM.fd_restore(this.pointer, copy.toFloat());
      if (result !== 0) {
        alert("Load failed");
      }
    } finally {
      WASM.free(ptr);
    }
  }

  dealloc() {
    WASM.free(this.cartCopyPtr);
    WASM.fd_destroy(this.pointer);
  }

  breakpoint: number = -1;
  setBreakpoint(bp: number) {
    this.breakpoint = bp;
    WASM.fd_set_breakpoint(this.pointer, bp);
    this.changed.dispatch();
  }

  reset() {
    WASM.fd_reset(this.pointer);
    this.changed.dispatch();
  }

  step(): number {
    const cycles = WASM.fd_step(this.pointer);
    this.changed.dispatch();
    return cycles;
  }

  stepCycles(cycles: number): number {
    const actual = WASM.fd_step_cycles(this.pointer, cycles);
    this.changed.dispatch();
    return actual;
  }

  stepMs(ms: number): number {
    const cycles = WASM.fd_step_ms(this.pointer, ms);
    this.changed.dispatch();
    return cycles;
  }

  _inputStatus(raw: number): Record<Input, boolean> {
    const mapping = {} as Record<Input, boolean>;
    for (let bit = 0; bit < 8; bit++) {
      const mask = 1 << bit;
      const input = InputBitMapping[mask];
      const value = Boolean(raw & mask);
      mapping[input] = value;
    }
    return mapping;
  }

  inputPress(input: Input) {
    const val = InputBitMapping[input];
    return this._inputStatus(WASM.fd_input_press(this.pointer, val));
  }

  inputRelease(input: Input) {
    const val = InputBitMapping[input];
    return this._inputStatus(WASM.fd_input_release(this.pointer, val));
  }

  inputReleaseAll() {
    return this._inputStatus(WASM.fd_input_release(this.pointer, 0xff));
  }

  *disassemble(): IterableIterator<[number, string]> {
    const stringPtr = WASM.malloc(16);
    try {
      let i = 0;
      while (i < this.cart.length) {
        const byte0 = this.cart[i];
        const byte1 = this.cart[i + 1] || 0;
        const byte2 = this.cart[i + 2] || 0;

        const outChunk = U8Chunk.fromFloat(
          WASM.fd_disassemble(stringPtr, byte0, byte1, byte2)
        );
        const utf8 = new TextDecoder("utf-8").decode(outChunk);

        yield [i, utf8];

        i += WASM.fd_instr_len(byte0);
      }
    } finally {
      WASM.free(stringPtr);
    }
  }
}
