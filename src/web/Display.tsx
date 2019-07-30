import React from "react";
import cx from "classnames";
import { Signal } from "micro-signals";

import nano from "./nano";
import { PtrMatrix } from "../wasm";

const CSS = {
  root: nano.rule({
    position: "relative",
    backgroundColor: "white",
    padding: "1px",
    flex: "0 auto"
  }),

  draw: nano.rule({
    position: "relative",
    display: "block",
    margin: "-1px"
  }),

  grid: nano.rule({
    position: "absolute",
    top: "0",
    left: "0",
    transformOrigin: "0 0",
    backgroundSize: `8px 8px`,
    zIndex: 0
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
  className?: string;
  pixels: PtrMatrix;
  scale?: number;
  signal?: Signal<any>;
  gridColor?: string;
}) {
  const drawRef = React.useRef<HTMLCanvasElement>(null);
  const render = React.useCallback(() => {
    if (!drawRef.current) {
      return;
    }

    const ctx = drawRef.current.getContext("2d")!;
    ctx.putImageData(imageData(props.pixels), PADDING, PADDING);
  }, [drawRef.current]);

  React.useEffect(render);

  React.useEffect(() => {
    if (props.signal) {
      const signal = props.signal;
      signal.add(render);
      return () => signal.remove(render);
    }
  }, [props.signal]);

  const scale = props.scale || 1;
  const width = props.pixels.width + PADDING * 2;
  const height = props.pixels.height + PADDING * 2;

  return (
    <div className={cx(CSS.root, props.className)}>
      {props.gridColor && (
        <div
          className={CSS.grid}
          style={{
            width: props.pixels.width + PADDING * 2,
            height: props.pixels.height + PADDING * 2,
            transform: `scale(${scale})`,
            backgroundImage: [
              `linear-gradient(to right, ${props.gridColor} 2px, transparent 1px)`,
              `linear-gradient(to bottom, ${props.gridColor} 2px, transparent 1px)`
            ].join(",")
          }}
        />
      )}
      <canvas
        ref={drawRef}
        className={CSS.draw}
        width={width}
        height={height}
        style={{ width: width * scale }}
      />
    </div>
  );
}
