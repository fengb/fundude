import React from "react";
import cx from "classnames";
import { Signal } from "micro-signals";

import nano from "./nano";
import { PtrMatrix } from "../wasm";
import { clamp } from "./smalldash";

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

const TRANSPARENCY_PALETTE = [0, 85, 170, 255];

const WHITE = Uint8Array.of(15, 56, 15, 1);

const FADE_PER_FRAME = 25;

export default function Display(props: {
  className?: string;
  pixels: PtrMatrix;
  scale?: number;
  signal?: Signal<any>;
  gridColor?: string;
}) {
  const [imageData] = React.useState(() => {
    const imageData = new ImageData(props.pixels.width, props.pixels.height);
    for (let i = 0; i < props.pixels.length(); i++) {
      imageData.data.set(WHITE, 4 * i);
    }
    return imageData;
  });

  const drawRef = React.useRef<HTMLCanvasElement>(null);

  const render = React.useCallback(() => {
    if (!drawRef.current) return;

    const ctx = drawRef.current.getContext("2d")!;
    for (let i = 0; i < props.pixels.length(); i++) {
      const colorIndex = props.pixels.base[i];
      if (TRANSPARENCY_PALETTE.hasOwnProperty(colorIndex)) {
        const alphaIdx = 4 * i + 3;
        const oldAlpha = imageData.data[alphaIdx];
        imageData.data[alphaIdx] = clamp(
          TRANSPARENCY_PALETTE[colorIndex],
          oldAlpha - FADE_PER_FRAME,
          oldAlpha + FADE_PER_FRAME
        );
      }
    }
    ctx.putImageData(imageData, PADDING, PADDING);
  }, []);

  React.useEffect(render, [drawRef.current]);

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
