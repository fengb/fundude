//@ts-ignore
import WASM from "../../zig-cache/fundude.wasm";
import PicoSignal from "./PicoSignal";

Object.assign(window, { WASM });

export type Matrix<T> = T & {
  width: number;
  height: number;
};

type TypedArrayConstructor<T> = {
  new (buffer: ArrayBufferLike, byteOffset: number, length?: number): T;
};

type Chunk<T> = T & {
  ptr: number;
  toFloat: () => number;
};
const Chunk = {
  create<T>(
    constructor: TypedArrayConstructor<T>,
    ptr: number,
    length: number
  ): Chunk<T> {
    return Object.assign(new constructor(WASM.memory.buffer, ptr, length), {
      ptr,
      toFloat: () => Chunk.toFloat(ptr, length)
    });
  },

  fromFloat<T>(constructor: TypedArrayConstructor<T>, value: number): Chunk<T> {
    let buf = new ArrayBuffer(8);
    new Float64Array(buf)[0] = value;
    let u32s = new Uint32Array(buf);
    return Chunk.create(constructor, u32s[0], u32s[1]);
  },

  u8FromFloat(value: number) {
    return Chunk.fromFloat(Uint8Array, value);
  },

  u16FromFloat(value: number) {
    return Chunk.fromFloat(Uint16Array, value);
  },

  f32FromFloat(value: number) {
    return Chunk.fromFloat(Float32Array, value);
  },

  toFloat(ptr: number, length: number): number {
    let buf = new ArrayBuffer(8);
    let u32s = new Uint32Array(buf);
    u32s[0] = ptr;
    u32s[1] = length;
    return new Float64Array(buf)[0];
  }
};

const MatrixChunk = {
  fromFloat(value: number): Matrix<Uint8Array> {
    let buf = new ArrayBuffer(8);
    new Float64Array(buf)[0] = value;
    let u16s = new Uint16Array(buf);
    const ptr = u16s[0] | (u16s[1] << 16);
    const width = u16s[2];
    const height = u16s[3];
    return Object.assign(
      new Uint8Array(WASM.memory.buffer, ptr, width * height),
      { width, height }
    );
  }
};

export const MMU_OFFSETS = {
  shift: 0x8000,
  segments: [
    { start: 0x8000, end: 0xa000 - 1, name: "vram" },
    { start: 0xc000, end: 0xe000 - 1, name: "ram" },
    { start: 0xfe00, end: 0xfea0 - 1, name: "oam" },
    { start: 0xff00, end: 0xff4c - 1, name: "io" },
    { start: 0xff80, end: 0xffff - 1, name: "himem" }
  ]
};

enum InputBitMapping {
  right = 1,
  left = 2,
  up = 4,
  down = 8,

  a = 16,
  b = 32,
  select = 64,
  start = 128
}

export type Input = keyof typeof InputBitMapping;

export default class FundudeWasm {
  public changed = new PicoSignal<void>();

  private readonly pointer: number;
  cart: Uint8Array;
  private cartCopyPtr: number;

  constructor(cart: Uint8Array) {
    this.pointer = WASM.fd_alloc();
    this.init(cart);
  }

  screen() {
    return MatrixChunk.fromFloat(WASM.fd_screen(this.pointer));
  }

  background() {
    return MatrixChunk.fromFloat(WASM.fd_background(this.pointer));
  }

  window() {
    return MatrixChunk.fromFloat(WASM.fd_window(this.pointer));
  }

  sprites() {
    return MatrixChunk.fromFloat(WASM.fd_sprites(this.pointer));
  }

  patterns() {
    return MatrixChunk.fromFloat(WASM.fd_patterns(this.pointer));
  }

  _asStereo(value: Float32Array) {
    return Object.assign(this, {
      left: value.slice(0, value.length / 2),
      right: value.slice(0, value.length / 2)
    });
  }

  audio() {
    return this._asStereo(Chunk.f32FromFloat(WASM.fd_audio(this.pointer)));
  }

  audioSquare1() {
    return this._asStereo(
      Chunk.f32FromFloat(WASM.fd_audio_square1(this.pointer))
    );
  }

  audioSquare2() {
    return this._asStereo(
      Chunk.f32FromFloat(WASM.fd_audio_square2(this.pointer))
    );
  }

  audioWave() {
    return this._asStereo(Chunk.f32FromFloat(WASM.fd_audio_wave(this.pointer)));
  }

  audioNoise() {
    return this._asStereo(
      Chunk.f32FromFloat(WASM.fd_audio_noise(this.pointer))
    );
  }

  cpu() {
    const raw = Chunk.u16FromFloat(WASM.fd_cpu_reg(this.pointer));
    return Object.assign(raw, {
      AF: () => raw[0],
      BC: () => raw[1],
      DE: () => raw[2],
      HL: () => raw[3],
      SP: () => raw[4],
      PC: () => raw[5]
    });
  }

  mmu() {
    return Chunk.u8FromFloat(WASM.fd_mmu(this.pointer));
  }

  init(cart: Uint8Array) {
    if (this.cartCopyPtr) {
      WASM.free(this.cartCopyPtr);
    }

    this.cart = cart;
    this.cartCopyPtr = WASM.malloc(cart.length);
    const copy = Chunk.create(Uint8Array, this.cartCopyPtr, cart.length);
    copy.set(cart);

    const status = WASM.fd_init(this.pointer, copy.toFloat());
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

  dealloc() {
    WASM.free(this.cartCopyPtr);
    WASM.free(this.pointer);
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
    const fd = new FundudeWasm(this.cart);
    try {
      while (true) {
        const addr = fd.cpu().PC();
        const outChunk = Chunk.u8FromFloat(WASM.fd_disassemble(fd.pointer));

        if (!outChunk.length) {
          return;
        }
        yield [addr, new TextDecoder("utf-8").decode(outChunk)];
      }
    } finally {
      fd.dealloc();
    }
  }
}
