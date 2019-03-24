import Display from "./display";
import FundudeWasm from "./wasm";

const container = document.getElementById("display");
if (container instanceof HTMLCanvasElement) {
  FundudeWasm.ready().then(() => {
    const fd = new FundudeWasm();
    const display = new Display(container, fd);
    display.show();
  });
}
