//@ts-ignore
import WASM from "../../build/fundude.wasm";

import { Signal } from "micro-signals";

Object.assign(window, { WASM });

export interface GBInstruction {
  addr: number;
  text: string;
}

export interface PtrMatrix extends PtrArray {
  width: number;
  height: number;
}

export class PtrArray {
  public base: Uint8Array;
  readonly ptr: number;

  constructor(ptr: number, length: number) {
    this.ptr = ptr;
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
      this.base = new Uint8Array(WASM.memory.buffer, this.ptr, length);
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

function tuple<T1, T2>(t1: T1, t2: T2): [T1, T2] {
  return [t1, t2];
}

export const MMU_OFFSETS = {
  shift: 0x8000,
  segments: {
    vram: tuple(0x8000, 0xa000),
    ram: tuple(0xc000, 0xe000),
    oam: tuple(0xfe00, 0xfea0),
    ioPorts: tuple(0xff00, 0xff4c),
    himem: tuple(0xff80, 0xffff)
  }
};

export default class FundudeWasm {
  public changed = new Signal<void>();

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

  display() {
    return PtrArray.matrix(this.pointer, this.width, this.height);
  }

  background() {
    return PtrArray.matrix(WASM.fd_background_ptr(this.pointer), 256, 256);
  }

  window() {
    return PtrArray.matrix(WASM.fd_window_ptr(this.pointer), 256, 256);
  }

  tileData() {
    return PtrArray.matrix(WASM.fd_tile_data_ptr(this.pointer), 256, 96);
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
    WASM.fd_init(this.pointer, cart.length, this.cartClone.ptr);

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

  step() {
    WASM.fd_step(this.pointer);
    this.changed.dispatch();
  }

  stepFrame(frames = 1) {
    WASM.fd_step_frames(this.pointer, frames);
    this.changed.dispatch();
  }

  static *disassemble(cart: Uint8Array): IterableIterator<GBInstruction> {
    const fd = new FundudeWasm(cart);
    try {
      while (true) {
        const addr = fd.cpu().PC();
        const outPtr = WASM.fd_disassemble(fd.pointer);
        if (!outPtr) {
          return;
        }
        yield {
          addr,
          text: toUTF8(outPtr)
        };
      }
    } finally {
      fd.dealloc();
    }
  }
}
