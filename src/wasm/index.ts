//@ts-ignore
import fundude from "../../build/fundude";
import { deferred } from "../promise";

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

  constructor() {
    this.pointer = Module.ccall("init", "number", [], []);

    this.width = Module.ccall("display_width", "number", [], []);
    this.height = Module.ccall("display_height", "number", [], []);
    this.display = Module.HEAP8.subarray(
      this.pointer,
      this.pointer + this.width * this.height
    );
  }
}

Object.assign(window, { FundudeWasm, Module });
