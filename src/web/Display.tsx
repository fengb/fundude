import React from "react";

const PADDING = 1;

const PALETTE: Record<number, Uint8Array> = {
  0: Uint8Array.of(15, 56, 15, 0),
  1: Uint8Array.of(15, 56, 15, 85),
  2: Uint8Array.of(15, 56, 15, 170),
  3: Uint8Array.of(15, 56, 15, 255)
};

function imageData(pixels: Uint8Array, width: number) {
  const imageData = new ImageData(width, pixels.length / width);
  for (let i = 0; i < pixels.length; i++) {
    const colorIndex = pixels[i];
    const color = PALETTE[colorIndex] || Uint8Array.of(255, 0, 0, 255);
    imageData.data.set(color, 4 * i);
  }
  return imageData;
}

export default function Display(props: {
  pixels: Uint8Array;
  width: number;
  height: number;
}) {
  const ref = React.useRef<HTMLCanvasElement>(null);
  React.useEffect(() => {
    if (!ref.current) {
      return;
    }

    const ctx = ref.current.getContext("2d")!;
    ctx.putImageData(imageData(props.pixels, props.width), PADDING, PADDING);
  });

  return (
    <canvas
      id="display"
      ref={ref}
      width={props.width + PADDING * 2}
      height={props.height + PADDING * 2}
    />
  );
}
