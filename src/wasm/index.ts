//@ts-ignore
import fundude from "../../build/fundude";

import { Signal } from "micro-signals";
import { deferred } from "./util";

const READY = deferred();

const Module = fundude({
  onRuntimeInitialized: READY.resolve
});

export type Palette = Record<number, Uint8Array>;
export interface GBInstruction {
  addr: number;
  text: string;
}

type PtrArray = Uint8Array & { ptr: number };

const PtrArray = {
  segment: function(ptr: number, length: number): PtrArray {
    const array = Module.HEAPU8.subarray(ptr, ptr + length);
    return Object.assign(array, { ptr });
  },
  clone: function(array: Uint8Array) {
    const ptr = Module._malloc(array.length);
    const ptrArray = PtrArray.segment(ptr, array.length);
    ptrArray.set(array);
    return ptrArray;
  }
};

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

const CART_OFFSET = 0x8000;

function memory(raw: Uint8Array) {
  return Object.assign(raw, {
    displayStart: CART_OFFSET,
    offsets: {
      vram: 0x8000 - CART_OFFSET,
      ram: 0xc000 - CART_OFFSET,
      oam: 0xfe00 - CART_OFFSET,
      io_ports: 0xff00 - CART_OFFSET,
      himem: 0xff80 - CART_OFFSET
    }
  });
}

export default class FundudeWasm {
  static ready() {
    return READY;
  }

  static boot(cart: Uint8Array) {
    return FundudeWasm.ready().then(() => new FundudeWasm(cart));
  }

  public changed = new Signal<void>();

  private readonly pointer: number;
  cart!: PtrArray;

  readonly width: number;
  readonly height: number;
  readonly display: Uint8Array;

  readonly registers: ReturnType<typeof registers>;
  readonly memory: ReturnType<typeof memory>;

  constructor(cart: Uint8Array) {
    this.pointer = Module._alloc();
    this.init(cart);

    this.width = Module._display_width();
    this.height = Module._display_height();
    this.display = PtrArray.segment(this.pointer, this.width * this.height);

    this.registers = registers(
      PtrArray.segment(Module._registers_ptr(this.pointer), 12)
    );
    this.memory = memory(
      PtrArray.segment(Module._memory_ptr(this.pointer), 0x8000)
    );
  }

  init(cart: Uint8Array) {
    if (this.cart) {
      Module._free(this.cart.ptr);
    }

    this.cart = PtrArray.clone(cart);
    Module._init(this.pointer, cart.length, this.cart.ptr);

    this.changed.dispatch();
  }

  dealloc() {
    if (this.cart) {
      Module._free(this.cart.ptr);
    }
    Module._free(this.pointer);
  }

  imageData(palette: Palette) {
    const imageData = new ImageData(this.width, this.height);
    for (let i = 0; i < this.display.length; i++) {
      const colorIndex = this.display[i];
      imageData.data.set(palette[colorIndex], 4 * i);
    }
    return imageData;
  }

  breakpoint: number = -1;
  setBreakpoint(bp: number) {
    this.breakpoint = bp;
    Module._set_breakpoint(this.pointer, bp);
    this.changed.dispatch();
  }

  step() {
    Module._step(this.pointer);
    this.changed.dispatch();
  }

  stepFrame(frames = 1) {
    Module._step_frames(this.pointer, frames);
    this.changed.dispatch();
  }

  static *disassemble(cart: Uint8Array): IterableIterator<GBInstruction> {
    const fd = new FundudeWasm(cart);
    const outPtr = Module._malloc(100);
    try {
      let addr = 0;
      while (true) {
        addr = Module._disassemble(fd.pointer, outPtr);
        if (addr < 0) {
          return;
        }
        yield {
          addr,
          text: Module.UTF8ToString(outPtr)
        };
      }
    } finally {
      Module._free(outPtr);
      fd.dealloc();
    }
  }
}
