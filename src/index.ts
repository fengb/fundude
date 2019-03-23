import Display from "./display";
import { NINTENDO } from "./data";
import "./wasm";

const container = document.getElementById("display");
if (container instanceof HTMLCanvasElement) {
  const display = new Display(container);
  display.show(NINTENDO);
}

