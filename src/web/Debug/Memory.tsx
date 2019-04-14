import React, { memo } from "react";
import { times } from "lodash";
import { style } from "typestyle";
import FundudeWasm from "../../wasm";
import LazyScroller from "../LazyScroller";

const CSS = {
  root: style({
    display: "flex",
    flexDirection: "column",
    height: "100%",
    maxHeight: "100vh"
  }),
  wrapper: style({
    fontFamily: "monospace"
  }),
  row: style({
    display: "flex"
  }),
  addr: style({
    flex: "1 1 auto"
  }),
  cell: style({
    flex: "1 1 auto",
    textAlign: "center"
  })
};

const WIDTH = 16;

function MemoryOutput(props: {
  mem: Uint8Array;
  displayStart: number;
  focus: number;
}) {
  const height = props.mem.length / WIDTH;
  return (
    <LazyScroller
      childWidth={430}
      childHeight={15}
      totalChildren={height}
      focus={Math.floor(props.focus / WIDTH)}
    >
      {row => (
        <div className={CSS.row}>
          <strong className={CSS.addr}>
            $
            {(props.displayStart + row * WIDTH)
              .toString(16)
              .padStart(4, "0")
              .toUpperCase()}
          </strong>
          {times(WIDTH, col => (
            <span key={col} className={CSS.cell}>
              {props.mem[row * WIDTH + col]
                .toString(16)
                .padStart(2, "0")
                .toUpperCase()}
            </span>
          ))}
        </div>
      )}
    </LazyScroller>
  );
}

export default function Memory(props: { fd: FundudeWasm }) {
  const [focus, setFocus] = React.useState(0);
  const mem = props.fd.memory;
  return (
    <div className={CSS.root}>
      <div>
        <button onClick={() => setFocus(mem.offsets.vram)}>VRAM</button>
        <button onClick={() => setFocus(mem.offsets.ram)}>RAM</button>
        <button onClick={() => setFocus(mem.offsets.oam)}>OAM</button>
        <button onClick={() => setFocus(mem.offsets.io_ports)}>IO Ports</button>
        <button onClick={() => setFocus(mem.offsets.himem)}>HIMEM</button>
      </div>
      <div className={CSS.wrapper}>
        <MemoryOutput mem={mem} displayStart={mem.displayStart} focus={focus} />
      </div>
    </div>
  );
}
