import React from "react";
import { style } from "typestyle";

const CSS = {
  root: style({
    display: "block",
    backgroundSize: "8px 8px",
    backgroundImage: [
      "linear-gradient(to right, lightgray 2px, transparent 1px)",
      "linear-gradient(to bottom, lightgray 2px, transparent 1px)"
    ].join(",")
  })
};

const PADDING = 1;

const PALETTE: Record<number, Uint8Array> = {
  0: Uint8Array.of(15, 56, 15, 0),
  1: Uint8Array.of(15, 56, 15, 85),
  2: Uint8Array.of(15, 56, 15, 170),
  3: Uint8Array.of(15, 56, 15, 255)
};

interface Matrix extends Uint8Array {
  width: number;
  height: number;
}

function imageData(pixels: Matrix) {
  const imageData = new ImageData(pixels.width, pixels.height);
  for (let i = 0; i < pixels.length; i++) {
    const colorIndex = pixels[i];
    const color = PALETTE[colorIndex] || Uint8Array.of(255, 0, 0, 255);
    imageData.data.set(color, 4 * i);
  }
  return imageData;
}

export default function Display(props: { pixels: Matrix; scale?: number }) {
  const ref = React.useRef<HTMLCanvasElement>(null);
  React.useEffect(() => {
    if (!ref.current) {
      return;
    }

    const ctx = ref.current.getContext("2d")!;
    ctx.putImageData(imageData(props.pixels), PADDING, PADDING);
  });

  return (
    <canvas
      className={CSS.root}
      ref={ref}
      width={props.pixels.width + PADDING * 2}
      height={props.pixels.height + PADDING * 2}
    />
  );
}
