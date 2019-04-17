import React from "react";
import { times, map } from "lodash";
import { style } from "typestyle";
import FundudeWasm, { MEMORY_OFFSETS } from "../../wasm";
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

const REGION_CSS: Record<string, string> = {
  vram: style({ backgroundColor: "purple" }),
  ram: style({ backgroundColor: "brown" }),
  oam: style({ backgroundColor: "pink" }),
  ioPorts: style({ backgroundColor: "yellow" }),
  himem: style({ backgroundColor: "blue" })
};

const MEMLOC_CSS: Record<number, string> = {};
for (const [key, tuple] of Object.entries(MEMORY_OFFSETS.segments)) {
  for (let loc = tuple[0]; loc < tuple[1]; loc++) {
    MEMLOC_CSS[loc] = REGION_CSS[key];
  }
}

const WIDTH = 16;

function MemoryOutput(props: {
  mem: FundudeWasm["memory"];
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
            ${hex4(MEMORY_OFFSETS.shift + row * WIDTH)}
          </strong>
          {times(WIDTH, col => {
            const i = row * WIDTH + col;
            return (
              <span
                key={col}
                className={`${CSS.cell} ${
                  props.highlightClasses[i + MEMORY_OFFSETS.shift]
                } ${MEMLOC_CSS[i + MEMORY_OFFSETS.shift]}`}
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
        {map(MEMORY_OFFSETS.segments, (tuple, key) => (
          <button
            key={key}
            className={REGION_CSS[key]}
            onClick={() => setFocus(tuple[0] - MEMORY_OFFSETS.shift)}
          >
            {key}
          </button>
        ))}
      </div>
      <MemoryOutput
        mem={mem}
        focus={focus}
        highlightClasses={{
          [props.fd.registers.HL()]: CSS.hl,
          [props.fd.registers.SP()]: CSS.sp
        }}
      />
    </div>
  );
}
