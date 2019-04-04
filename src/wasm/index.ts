import Display from "./display";
import { EMPTY } from "./data";
import FundudeWasm from "./wasm";

const container = document.getElementById("display");
if (container instanceof HTMLCanvasElement) {
  FundudeWasm.ready().then(() => {
    requestAnimationFrame(timestamp => {
      const fd = new FundudeWasm(timestamp, EMPTY);
      const display = new Display(container, fd);
      display.show();
      console.log(fd.µs());
    });
  });
}
