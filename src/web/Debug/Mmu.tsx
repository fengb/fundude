import React from "react";
import { style } from "typestyle";
import classnames from "classnames";

import map from "lodash/map";
import times from "lodash/times";

import FundudeWasm, { PtrArray, MMU_OFFSETS } from "../../wasm";
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
  controls: style({
    display: "flex",
    fontFamily: "monospace",
    textAlign: "center"
  }),
  custom: style({
    display: "flex",
    width: "50px"
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
  vram: style({ backgroundColor: "#ffaaaa" }),
  ram: style({ backgroundColor: "#ffffaa" }),
  oam: style({ backgroundColor: "#aaffaa" }),
  io: style({ backgroundColor: "#aaffff" }),
  himem: style({ backgroundColor: "#aaaaff" })
};

const MEMLOC_CSS: Record<number, string> = {};
for (const key in MMU_OFFSETS.segments) {
  const tuple = MMU_OFFSETS.segments[key];
  for (let loc = tuple[0]; loc <= tuple[1]; loc++) {
    MEMLOC_CSS[loc] = REGION_CSS[key];
  }
}

const WIDTH = 16;

function MmuOutput(props: {
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
      focus={Math.floor((props.focus - MMU_OFFSETS.shift) / WIDTH)}
    >
      {row => (
        <div className={CSS.row}>
          <strong className={CSS.addr}>
            ${hex4(MMU_OFFSETS.shift + row * WIDTH)}
          </strong>
          {times(WIDTH, col => {
            const i = row * WIDTH + col;
            const loc = row * WIDTH + col + MMU_OFFSETS.shift;
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

export default function Mmu(props: { fd: FundudeWasm }) {
  const [focus, setFocus] = React.useState(0);
  const cpu = props.fd.cpu();
  return (
    <div className={CSS.root}>
      <div className={CSS.controls}>
        {map(MMU_OFFSETS.segments, (tuple, key) => (
          <div key={key} className={REGION_CSS[key]}>
            <div>{key}</div>
            <button onClick={() => setFocus(tuple[0])}>
              {hex4(tuple[0])}
            </button>
            <button onClick={() => setFocus(tuple[1])}>
              {hex4(tuple[1])}
            </button>
          </div>
        ))}
        <Form
          className={CSS.custom}
          onSubmit={({ search }) => setFocus(parseInt(String(search), 16))}
        >
          <input name="search" pattern="[0-9a-fA-F]*" placeholder="Addr" />
        </Form>
      </div>
      <MmuOutput
        mem={props.fd.mmu()}
        focus={focus}
        highlightClasses={{
          [cpu.HL()]: CSS.hl,
          [cpu.SP()]: CSS.sp
        }}
      />
    </div>
  );
}
