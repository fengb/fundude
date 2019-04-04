//@ts-ignore
import fundude from "../../build/fundude";
import { deferred } from "./promise";

const READY = deferred<void>();

const Module = fundude({
  onRuntimeInitialized: READY.resolve
});

export default class FundudeWasm {
  static ready() {
    return READY;
  }

  private pointer: number;

  readonly width: number;
  readonly height: number;
  readonly display: Uint8Array;

  constructor(ms: number, cart: Uint8Array) {
    this.pointer = Module.ccall(
      "init",
      "number",
      ["number", "array"],
      [ms * 1000, cart]
    );

    this.width = Module.ccall("display_width", "number", [], []);
    this.height = Module.ccall("display_height", "number", [], []);
    this.display = Module.HEAP8.subarray(
      this.pointer,
      this.pointer + this.width * this.height
    );
  }

  µs() {
    return Module.ccall("fd_us", "number", ["number"], [this.pointer]);
  }
}

Object.assign(window, { FundudeWasm, Module });
