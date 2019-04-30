import React from "react";
import { style } from "typestyle";
import { PtrMatrix } from "../wasm";
import { Signal } from "micro-signals";

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

function imageData(pixels: PtrMatrix) {
  const imageData = new ImageData(pixels.width, pixels.height);
  for (let i = 0; i < pixels.length(); i++) {
    const colorIndex = pixels.base[i];
    const color = PALETTE[colorIndex] || Uint8Array.of(255, 0, 0, 255);
    imageData.data.set(color, 4 * i);
  }
  return imageData;
}

export default function Display(props: {
  pixels: PtrMatrix;
  scale?: number;
  signal?: Signal<any>;
}) {
  const ref = React.useRef<HTMLCanvasElement>(null);
  const render = React.useCallback(() => {
    if (!ref.current) {
      return;
    }

    const ctx = ref.current.getContext("2d")!;
    ctx.putImageData(imageData(props.pixels), PADDING, PADDING);
  }, [ref.current]);

  React.useEffect(render);

  React.useEffect(() => {
    if (props.signal) {
      const signal = props.signal;
      signal.add(render);
      return () => signal.remove(render);
    }
  }, [props.signal]);

  return (
    <canvas
      className={CSS.root}
      ref={ref}
      width={props.pixels.width + PADDING * 2}
      height={props.pixels.height + PADDING * 2}
    />
  );
}
