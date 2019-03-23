//@ts-ignore
import fundude from "../../build/fundude";

const Module = fundude();
Object.assign(window, { Module });

export default class FundudeWasm {
  private pointer: number;
  constructor() {
    this.pointer = Module.ccall("init", "number", [], []);
  }
}
