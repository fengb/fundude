import React, { memo } from "react";
import { times } from "lodash";
import { style } from "typestyle";
import FundudeWasm from "../../wasm";
import LazyScroller from "../LazyScroller";
import { hex2, hex4 } from "./util";

const CSS = {
  root: style({
    display: "flex",
    flexDirection: "column",
    height: "100%",
    maxHeight: "100vh"
  }),
  row: style({
    display: "flex",
    fontFamily: "monospace"
  }),
  addr: style({
    flex: "1 1 auto"
  }),
  cell: style({
    flex: "1 1 auto",
    textAlign: "center"
  }),

  hl: style({
    backgroundColor: "#d0ffff"
  }),
  sp: style({
    backgroundColor: "#ffd0ff"
  })
};

const WIDTH = 16;

function MemoryOutput(props: {
  mem: Uint8Array;
  displayStart: number;
  focus: number;
  highlightClasses: Record<number, string>;
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
            ${hex4(props.displayStart + row * WIDTH)}
          </strong>
          {times(WIDTH, col => {
            const i = row * WIDTH + col;
            return (
              <span
                key={col}
                className={`${CSS.cell} ${
                  props.highlightClasses[i + props.displayStart]
                }`}
              >
                {hex2(props.mem[i])}
              </span>
            );
          })}
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
      <MemoryOutput
        mem={mem}
        displayStart={mem.displayStart}
        focus={focus}
        highlightClasses={{
          [props.fd.registers.HL()]: CSS.hl,
          [props.fd.registers.SP()]: CSS.sp
        }}
      />
    </div>
  );
}
