//@ts-ignore
import WASM from "../../build/fundude.wasm";

import { Signal } from "micro-signals";

Object.assign(window, { WASM });

export interface GBInstruction {
  addr: number;
  text: string;
}

interface PtrArray extends Uint8Array {
  ptr: number;
}

interface PtrMatrix extends PtrArray {
  width: number;
  height: number;
}

const PtrArray = {
  segment(ptr: number, length: number): PtrArray {
    const array = new Uint8Array(WASM.memory.buffer, ptr, length);
    return Object.assign(array, { ptr });
  },
  matrix(ptr: number, width: number, height: number) {
    return Object.assign(PtrArray.segment(ptr, width * height), {
      width,
      height
    });
  },
  clone(array: Uint8Array) {
    const ptr = WASM.malloc(array.length);
    const ptrArray = PtrArray.segment(ptr, array.length);
    ptrArray.set(array);
    return ptrArray;
  }
};

function toUTF8(ptr: number) {
  const scan = new Uint8Array(WASM.memory.buffer, ptr);
  const end = scan.findIndex(c => c === 0);
  const rawBytes = scan.subarray(0, end);
  return new TextDecoder("utf-8").decode(rawBytes);
}

function registers(raw: Uint8Array) {
  return {
    raw,
    AF: () => raw[0] + (raw[1] << 8),
    BC: () => raw[2] + (raw[3] << 8),
    DE: () => raw[4] + (raw[5] << 8),
    HL: () => raw[6] + (raw[7] << 8),
    SP: () => raw[8] + (raw[9] << 8),
    PC: () => raw[10] + (raw[11] << 8)
  };
}

function tuple<T1, T2>(t1: T1, t2: T2): [T1, T2] {
  return [t1, t2];
}

export const MEMORY_OFFSETS = {
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
  static ready() {
    return Promise.resolve();
  }

  static boot(cart: Uint8Array) {
    return FundudeWasm.ready().then(() => new FundudeWasm(cart));
  }

  public changed = new Signal<void>();

  private readonly pointer: number;
  cart!: PtrArray;

  readonly width: number;
  readonly height: number;
  readonly display: PtrMatrix;

  readonly background: PtrMatrix;
  readonly window: PtrMatrix;
  readonly tileData: PtrMatrix;

  readonly registers: ReturnType<typeof registers>;
  readonly memory: Uint8Array;

  constructor(cart: Uint8Array) {
    this.pointer = WASM.fd_alloc();
    this.init(cart);

    this.width = 160;
    this.height = 144;
    this.display = PtrArray.matrix(this.pointer, this.width, this.height);

    this.background = PtrArray.matrix(
      WASM.fd_background_ptr(this.pointer),
      256,
      256
    );
    this.window = PtrArray.matrix(WASM.fd_window_ptr(this.pointer), 256, 256);
    this.tileData = PtrArray.matrix(
      WASM.fd_tile_data_ptr(this.pointer),
      256,
      96
    );

    this.registers = registers(
      PtrArray.segment(WASM.fd_registers_ptr(this.pointer), 12)
    );
    this.memory = PtrArray.segment(WASM.fd_memory_ptr(this.pointer), 0x8000);
  }

  init(cart: Uint8Array) {
    if (this.cart) {
      WASM.free(this.cart.ptr);
    }

    this.cart = PtrArray.clone(cart);
    WASM.fd_init(this.pointer, cart.length, this.cart.ptr);

    this.changed.dispatch();
  }

  dealloc() {
    if (this.cart) {
      WASM.free(this.cart.ptr);
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
        const addr = fd.registers.PC();
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
