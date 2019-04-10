//@ts-ignore
import fundude from "../../build/fundude";

import { deferred, nextAnimationFrame } from "./promise";

const READY = deferred<void>();

const Module = fundude({
  onRuntimeInitialized: READY.resolve
});

export type Palette = Record<number, Uint8Array>;
export interface GBInstruction {
  addr: number;
  text: string;
}

type PtrArray = Uint8Array & { ptr: number };

function PtrArray(ptr: number, length: number): PtrArray {
  const array = Module.HEAPU8.subarray(ptr, ptr + length);
  return Object.assign(array, { ptr });
}

PtrArray.from = function(array: Uint8Array) {
  const ptrArray = PtrArray(Module._malloc(array.length), array.length);
  ptrArray.set(array);
  return ptrArray;
};

export default class FundudeWasm extends EventTarget {
  static ready() {
    return READY;
  }

  static boot(cart: Uint8Array) {
    return FundudeWasm.ready().then(ms => new FundudeWasm(cart));
  }

  private pointer: number;
  private cart: PtrArray;

  readonly width: number;
  readonly height: number;
  readonly display: Uint8Array;
  readonly registers: Uint8Array;

  programCounter: number;

  constructor(cart: Uint8Array) {
    super();
    this.cart = PtrArray.from(cart);

    this.pointer = Module.ccall(
      "init",
      "number",
      ["number", "number"],
      [cart.length, this.cart.ptr]
    );

    this.width = Module.ccall("display_width", "number", [], []);
    this.height = Module.ccall("display_height", "number", [], []);
    this.display = PtrArray(this.pointer, this.width * this.height);

    this.registers = PtrArray(
      Module.ccall("registers_ptr", "number", ["number"], [this.pointer]),
      12
    );
    this.programCounter = 0;
  }

  destroy() {
    Module._free(this.cart.ptr);
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

  step() {
    this.programCounter = Module.ccall(
      "step",
      "number",
      ["number"],
      [this.pointer]
    );
    this.dispatchEvent(
      new CustomEvent("programCounter", { detail: this.programCounter })
    );
  }

  stepFrame() {
    this.programCounter = Module.ccall(
      "stepFrame",
      "number",
      ["number"],
      [this.pointer]
    );
    this.dispatchEvent(
      new CustomEvent("programCounter", { detail: this.programCounter })
    );
  }

  *disassemble(): IterableIterator<GBInstruction> {
    const outPtr = Module._malloc(100);
    try {
      let addr = 0;
      while (true) {
        addr = Module.ccall(
          "disassemble",
          "number",
          ["number", "number"],
          [this.pointer, outPtr]
        );
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
    }
  }
}

Object.assign(window, { FundudeWasm, Module });
