import React from "react";
import FundudeWasm from "./wasm";

const PADDING = 1;

const PALETTE: Record<number, Uint8Array> = {
  0: Uint8Array.of(15, 56, 15, 0),
  1: Uint8Array.of(15, 56, 15, 85),
  2: Uint8Array.of(15, 56, 15, 170),
  3: Uint8Array.of(15, 56, 15, 255)
};

export default function Display({ fundude }: { fundude: FundudeWasm }) {
  const ref = React.useRef<HTMLCanvasElement>(null);
  React.useEffect(() => {
    if (!ref.current) {
      return;
    }

    const ctx = ref.current.getContext("2d")!;
    ctx.putImageData(fundude.imageData(PALETTE), PADDING, PADDING);
  }, [ref.current]);

  return (
    <canvas
      id="display"
      ref={ref}
      width={fundude.width + PADDING * 2}
      height={fundude.height + PADDING * 2}
    />
  );
}
