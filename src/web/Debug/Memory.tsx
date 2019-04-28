import React from "react";
import { times, map } from "lodash";
import { style } from "typestyle";
import classnames from "classnames";
import FundudeWasm, { PtrArray, MEMORY_OFFSETS } from "../../wasm";
import LazyScroller from "../LazyScroller";
import { hex2, hex4 } from "./util";
import Form from "../Form";

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
  focus: style({
    boxShadow: "inset 0 0 0 1px black"
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
  mem: PtrArray;
  focus: number;
  highlightClasses: Record<number, string>;
}) {
  const height = props.mem.length() / WIDTH;
  return (
    <LazyScroller
      childWidth={430}
      childHeight={15}
      totalChildren={height}
      focus={Math.floor((props.focus - MEMORY_OFFSETS.shift) / WIDTH)}
    >
      {row => (
        <div className={CSS.row}>
          <strong className={CSS.addr}>
            ${hex4(MEMORY_OFFSETS.shift + row * WIDTH)}
          </strong>
          {times(WIDTH, col => {
            const i = row * WIDTH + col;
            const loc = row * WIDTH + col + MEMORY_OFFSETS.shift;
            return (
              <span
                key={col}
                className={classnames(
                  CSS.cell,
                  props.highlightClasses[loc],
                  MEMLOC_CSS[loc],
                  loc === props.focus && CSS.focus
                )}
              >
                {hex2(props.mem.base[i] || 0)}
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
  const reg = props.fd.registers();
  return (
    <div className={CSS.root}>
      <div>
        {map(MEMORY_OFFSETS.segments, (tuple, key) => (
          <button
            key={key}
            className={REGION_CSS[key]}
            onClick={() => setFocus(tuple[0])}
          >
            {key}
            <br />${hex4(tuple[0])}
          </button>
        ))}
        <Form onSubmit={({ search }) => setFocus(parseInt(String(search), 16))}>
          <input name="search" pattern="[0-9a-fA-F]*" />
        </Form>
      </div>
      <MemoryOutput
        mem={props.fd.memory()}
        focus={focus}
        highlightClasses={{
          [reg.HL()]: CSS.hl,
          [reg.SP()]: CSS.sp
        }}
      />
    </div>
  );
}
