import Display from "./display";
import FundudeWasm from "./wasm";

const container = document.getElementById("display");
if (container instanceof HTMLCanvasElement) {
  FundudeWasm.ready().then(() => {
    requestAnimationFrame(timestamp => {
      const fd = new FundudeWasm(timestamp);
      const display = new Display(container, fd);
      display.show();
      console.log(fd.µs());
    });
  });
}
