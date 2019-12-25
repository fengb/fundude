//@ts-ignore
import WASM from "../../zig-cache/fundude.wasm";
import PicoSignal from "./PicoSignal";

Object.assign(window, { WASM });

export interface PtrMatrix extends PtrArray {
  width: number;
  height: number;
}

export class PtrArray {
  public base: Uint8Array;
  readonly ptr: number;
  readonly _length: number;

  constructor(ptr: number, length: number) {
    this.ptr = ptr;
    this._length = length;
    this.base = new Uint8Array(WASM.memory.buffer, ptr, length);
  }

  static clone(array: Uint8Array): PtrArray {
    const ptr = WASM.malloc(array.length);
    const ptrArray = new PtrArray(ptr, array.length);
    ptrArray.base.set(array);
    return ptrArray;
  }

  static matrix(ptr: number, width: number, height: number): PtrMatrix {
    return Object.assign(new PtrArray(ptr, width * height), {
      width,
      height
    });
  }

  length(): number {
    if (this.base.length == 0) {
      this.base = new Uint8Array(WASM.memory.buffer, this.ptr, this._length);
    }

    return this.base.length;
  }
}

function toUTF8(ptr: number) {
  const scan = new Uint8Array(WASM.memory.buffer, ptr);
  const end = scan.findIndex(c => c === 0);
  const rawBytes = scan.subarray(0, end);
  return new TextDecoder("utf-8").decode(rawBytes);
}

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
  cart!: Uint8Array;
  private cartClone?: PtrArray;

  readonly width: number;
  readonly height: number;

  constructor(cart: Uint8Array) {
    this.pointer = WASM.fd_alloc();
    this.init(cart);

    this.width = 160;
    this.height = 144;
  }

  screen() {
    return PtrArray.matrix(
      WASM.fd_screen_ptr(this.pointer),
      this.width,
      this.height
    );
  }

  background() {
    return PtrArray.matrix(WASM.fd_background_ptr(this.pointer), 256, 256);
  }

  window() {
    return PtrArray.matrix(WASM.fd_window_ptr(this.pointer), 256, 256);
  }

  sprites() {
    return PtrArray.matrix(
      WASM.fd_sprites_ptr(this.pointer),
      256 + 2 * 8,
      256 + 2 * 16
    );
  }

  patterns() {
    return PtrArray.matrix(WASM.fd_patterns_ptr(this.pointer), 8, 8 * 128 * 3);
  }

  cpu() {
    const raw = new PtrArray(WASM.fd_cpu_ptr(this.pointer), 12);
    return Object.assign(raw, {
      AF: () => raw.base[0] + (raw.base[1] << 8),
      BC: () => raw.base[2] + (raw.base[3] << 8),
      DE: () => raw.base[4] + (raw.base[5] << 8),
      HL: () => raw.base[6] + (raw.base[7] << 8),
      SP: () => raw.base[8] + (raw.base[9] << 8),
      PC: () => raw.base[10] + (raw.base[11] << 8)
    });
  }

  mmu() {
    return new PtrArray(WASM.fd_mmu_ptr(this.pointer), 0x8000);
  }

  init(cart: Uint8Array) {
    if (this.cartClone) {
      WASM.free(this.cartClone.ptr);
    }

    this.cart = cart;
    this.cartClone = PtrArray.clone(cart);

    const status = WASM.fd_init(this.pointer, cart.length, this.cartClone.ptr);
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
    if (this.cartClone) {
      WASM.free(this.cartClone.ptr);
    }
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

  stepFrame(frames = 1): number {
    const cycles = WASM.fd_step_frames(this.pointer, frames);
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

  static *disassemble(cart: Uint8Array): IterableIterator<[number, string]> {
    const fd = new FundudeWasm(cart);
    try {
      while (true) {
        const addr = fd.cpu().PC();
        const outPtr = WASM.fd_disassemble(fd.pointer);
        if (!outPtr) {
          return;
        }
        yield [addr, toUTF8(outPtr)];
      }
    } finally {
      fd.dealloc();
    }
  }
}
