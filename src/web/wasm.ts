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

export default class FundudeWasm {
  static ready() {
    return READY;
  }

  static boot(cart: Uint8Array) {
    return FundudeWasm.ready()
      .then(nextAnimationFrame)
      .then(ms => new FundudeWasm(ms, cart));
  }

  private pointer: number;
  private cartPtr: number;
  private cart: Uint8Array;

  readonly width: number;
  readonly height: number;
  readonly display: Uint8Array;

  constructor(ms: number, cart: Uint8Array) {
    this.cartPtr = Module._malloc(cart.length);
    this.cart = Module.HEAPU8.subarray(this.cartPtr, this.cartPtr + cart.length);
    this.cart.set(cart);

    this.pointer = Module.ccall(
      "init",
      "number",
      ["number", "number", "number"],
      [ms * 1000, cart.length, this.cartPtr]
    );

    console.log(this.cart);

    this.width = Module.ccall("display_width", "number", [], []);
    this.height = Module.ccall("display_height", "number", [], []);
    this.display = Module.HEAPU8.subarray(
      this.pointer,
      this.pointer + this.width * this.height
    );
  }

  imageData(palette: Palette) {
    const imageData = new ImageData(this.width, this.height);
    for (let i = 0; i < this.display.length; i++) {
      const colorIndex = this.display[i];
      imageData.data.set(palette[colorIndex], 4 * i);
    }
    return imageData;
  }

  µs() {
    return Module.ccall("fd_us", "number", ["number"], [this.pointer]);
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
