import React from "react";
import cx from "classnames";

import nano from "./nano";
import { Matrix } from "../wasm";
import PicoSignal from "../wasm/PicoSignal";

const CSS = {
  root: nano.rule({
    position: "relative",
    backgroundColor: "white",
    flex: "0 auto",
    overflow: "hidden",
  }),

  draw: nano.rule({
    position: "relative",
    display: "block",
    margin: "-1px",
  }),

  grid: nano.rule({
    position: "absolute",
    top: "0",
    left: "0",
    transformOrigin: "0 0",
    zIndex: 0,
    backgroundImage: [
      `linear-gradient(to right, lightgray 2px, transparent 1px)`,
      `linear-gradient(to bottom, lightgray 2px, transparent 1px)`,
    ].join(","),
    backgroundSize: "8px 8px",
    backgroundPosition: "-1px -1px",
  }),

  viewport: nano.rule({
    position: "absolute",
    width: "160px",
    height: "144px",
    zIndex: 1,
    boxShadow: "inset 0 0 2px 1px black",
  }),
};

const PADDING = 1;

const WHITE = Uint8Array.of(15, 56, 15, 255);

export default function Display(props: {
  className?: string;
  pixels: () => Matrix<Uint16Array>;
  scale?: number;
  signal?: PicoSignal<any>;
  viewports: [number, number][];
  gridColor?: string;
  blend?: boolean;
}) {
  const pixels = props.pixels();

  // const prev = React.useMemo(() => {
  //   return new Uint8Array(pixels.width * pixels.height);
  // }, []);

  const imageData = React.useMemo(() => {
    const imageData = new ImageData(pixels.width, pixels.height);
    for (let i = 0; i < pixels.length; i++) {
      imageData.data.set(WHITE, 4 * i);
    }
    return imageData;
  }, []);

  const drawRef = React.useRef<HTMLCanvasElement>(null);

  const render = React.useCallback(() => {
    if (!drawRef.current) return;

    const ctx = drawRef.current.getContext("2d")!;
    const pixels = props.pixels();
    // if (props.blend) {
    //   for (let i = 0; i < pixels.length; i++) {
    //     const shade = pixels[i];
    //     const prevAlpha = prev[i];
    //     // const newAlpha = TRANSPARENCY_PALETTE[shade];
    //     const newAlpha = shade * 85;
    //     imageData.data[4 * i + 3] = (prevAlpha + newAlpha) >> 1;
    //     prev[i] = newAlpha;
    //   }
    // } else {
    for (let i = 0; i < pixels.length; i++) {
      const pixel = pixels[i];
      // const newAlpha = TRANSPARENCY_PALETTE[shade];
      const r = (pixel >> 0) & 0b11111;
      const g = (pixel >> 5) & 0b11111;
      const b = (pixel >> 10) & 0b11111;
      const opaque = (pixel >> 15) & 0b1;

      imageData.data[4 * i + 0] = r << (8 - 5);
      imageData.data[4 * i + 1] = g << (8 - 5);
      imageData.data[4 * i + 2] = b << (8 - 5);
    }
    // }
    ctx.putImageData(imageData, PADDING, PADDING);
  }, []);

  React.useEffect(render, [drawRef.current, props.pixels]);

  React.useEffect(() => {
    if (props.signal) {
      const signal = props.signal;
      signal.add(render);
      return () => signal.remove(render);
    }
  }, [props.signal]);

  const scale = props.scale || 1;
  const width = pixels.width + PADDING * 2;
  const height = pixels.height + PADDING * 2;

  return (
    <div className={cx(CSS.root, props.className)}>
      {props.gridColor && (
        <div
          className={CSS.grid}
          style={{
            width: pixels.width,
            height: pixels.height,
            transform: `scale(${scale})`,
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
      {props.viewports.map((viewport) => (
        <div
          className={CSS.viewport}
          style={{
            left: viewport[0],
            top: viewport[1],
            transform: `scale(${scale})`,
          }}
        />
      ))}
    </div>
  );
}
