export const DIMENSIONS = [160, 144] as [160, 144];

const COLORS: Record<number, Uint8Array> = {
  0: Uint8Array.of(15, 56, 15, 0),
  1: Uint8Array.of(15, 56, 15, 85),
  2: Uint8Array.of(15, 56, 15, 170),
  3: Uint8Array.of(15, 56, 15, 255)
};

export default class Display {
  private ctx: CanvasRenderingContext2D;
  private imageData = new ImageData(...DIMENSIONS);

  constructor(private canvas: HTMLCanvasElement) {
    canvas.width = DIMENSIONS[0];
    canvas.height = DIMENSIONS[1];
    this.ctx = canvas.getContext("2d")!;
  }

  show(rawData: Uint8Array) {
    for (let i = 0; i < rawData.length; i++) {
      const colorIndex = rawData[i];
      this.imageData.data.set(COLORS[colorIndex], 4 * i);
    }
    this.ctx.putImageData(this.imageData, 0, 0);
  }
}
