//@ts-ignore
import WASM from "../../zig-cache/fundude.wasm";
import PicoSignal from "./PicoSignal";

Object.assign(window, { WASM });

export type Matrix<T> = T & {
  width: number;
  height: number;
};

function wasmArray(ptr: number, length: number) {
  return new Uint8Array(WASM.memory.buffer, ptr, length);
}

function wasmMatrix(
  ptr: number,
  width: number,
  height: number
): Matrix<Uint8Array> {
  return Object.assign(wasmArray(ptr, width * height), { width, height });
}

function toUTF8(ptr: number) {
  const scan = new Uint8Array(WASM.memory.buffer, ptr);
  const end = scan.indexOf(0);
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
  cart: Uint8Array;
  private cartCopyPtr: number;

  readonly width: number;
  readonly height: number;

  constructor(cart: Uint8Array) {
    this.pointer = WASM.fd_alloc();
    this.init(cart);

    this.width = 160;
    this.height = 144;
  }

  screen() {
    return wasmMatrix(
      WASM.fd_screen_ptr(this.pointer),
      this.width,
      this.height
    );
  }

  background() {
    return wasmMatrix(WASM.fd_background_ptr(this.pointer), 256, 256);
  }

  window() {
    return wasmMatrix(WASM.fd_window_ptr(this.pointer), 256, 256);
  }

  sprites() {
    return wasmMatrix(
      WASM.fd_sprites_ptr(this.pointer),
      256 + 2 * 8,
      256 + 2 * 16
    );
  }

  patterns() {
    return wasmMatrix(WASM.fd_patterns_ptr(this.pointer), 8, 8 * 128 * 3);
  }

  cpu() {
    const raw = wasmArray(WASM.fd_cpu_ptr(this.pointer), 12);
    return Object.assign(raw, {
      AF: () => raw[0] + (raw[1] << 8),
      BC: () => raw[2] + (raw[3] << 8),
      DE: () => raw[4] + (raw[5] << 8),
      HL: () => raw[6] + (raw[7] << 8),
      SP: () => raw[8] + (raw[9] << 8),
      PC: () => raw[10] + (raw[11] << 8)
    });
  }

  mmu() {
    return wasmArray(WASM.fd_mmu_ptr(this.pointer), 0x8000);
  }

  init(cart: Uint8Array) {
    if (this.cartCopyPtr) {
      WASM.free(this.cartCopyPtr);
    }

    this.cart = cart;
    this.cartCopyPtr = WASM.malloc(cart.length);
    const copy = wasmArray(this.cartCopyPtr, cart.length);
    copy.set(cart);

    const status = WASM.fd_init(this.pointer, cart.length, this.cartCopyPtr);
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

  *disassemble(): IterableIterator<[number, string]> {
    const fd = new FundudeWasm(this.cart);
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
