import FundudeWasm from "./wasm";

const COLORS: Record<number, Uint8Array> = {
  0: Uint8Array.of(15, 56, 15, 0),
  1: Uint8Array.of(15, 56, 15, 85),
  2: Uint8Array.of(15, 56, 15, 170),
  3: Uint8Array.of(15, 56, 15, 255)
};

export default class Display {
  private ctx: CanvasRenderingContext2D;
  private imageData: ImageData;

  constructor(private canvas: HTMLCanvasElement, private fd: FundudeWasm) {
    canvas.width = fd.width;
    canvas.height = fd.height;
    this.imageData = new ImageData(fd.width, fd.height);
    this.ctx = canvas.getContext("2d")!;
  }

  show() {
    const rawData = this.fd.display;
    for (let i = 0; i < rawData.length; i++) {
      const colorIndex = rawData[i];
      this.imageData.data.set(COLORS[colorIndex], 4 * i);
    }
    this.ctx.putImageData(this.imageData, 0, 0);
  }
}
