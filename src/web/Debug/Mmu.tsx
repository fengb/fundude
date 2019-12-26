import React from "react";
import cx from "classnames";
import { FixedSizeGrid } from "react-window";
import useDimensions from "react-use-dimensions";

import nano from "../nano";
import { hex2, hex4 } from "./util";

import FundudeWasm, { MMU_OFFSETS } from "../../wasm";
import Form from "../Form";

const CSS = {
  root: nano.rule({
    display: "flex",
    flexDirection: "column",
    flex: "1 1 0",
    maxHeight: "100vh"
  }),
  controls: nano.rule({
    display: "flex",
    fontFamily: "monospace",
    textAlign: "center"
  }),
  custom: nano.rule({
    display: "flex",
    width: "50px"
  }),

  output: nano.rule({
    fontFamily: "monospace",
    textAlign: "center",
    flex: "1 1 0"
  }),
  outputCell: nano.rule({
    "&.active": {
      boxShadow: "inset 0 0 0 1px black"
    }
  }),

  hl: nano.rule({
    backgroundColor: "#d0ffff"
  }),
  sp: nano.rule({
    backgroundColor: "#ffd0ff"
  })
};

const REGION_CSS: Record<string, string> = {
  vram: nano.rule({ backgroundColor: "#ffaaaa" }),
  ram: nano.rule({ backgroundColor: "#ffffaa" }),
  oam: nano.rule({ backgroundColor: "#aaffaa" }),
  io: nano.rule({ backgroundColor: "#aaffff" }),
  himem: nano.rule({ backgroundColor: "#aaaaff" })
};

const MEMLOC_CSS: Record<number, string> = {};
for (const segment of MMU_OFFSETS.segments) {
  for (let loc = segment.start; loc <= segment.end; loc++) {
    MEMLOC_CSS[loc] = REGION_CSS[segment.name];
  }
}

const WIDTH = 16;

function MmuOutput(props: {
  mem: () => Uint8Array;
  focus: number;
  highlightClasses: Record<number, string>;
}) {
  const [rootRef, { height }] = useDimensions();
  const gridRef = React.createRef<FixedSizeGrid>();

  const mem = props.mem();

  React.useEffect(() => {
    const i = props.focus - MMU_OFFSETS.shift;
    gridRef.current &&
      gridRef.current.scrollToItem({
        columnIndex: i % WIDTH,
        rowIndex: i / WIDTH
      });
  }, [gridRef.current, props.focus]);

  return (
    <div ref={rootRef} className={CSS.output}>
      <FixedSizeGrid
        ref={gridRef}
        height={height || 0}
        width={430}
        columnCount={WIDTH}
        rowCount={mem.length / WIDTH}
        columnWidth={25}
        rowHeight={15}
      >
        {({ columnIndex, rowIndex, style }) => {
          const i = rowIndex * WIDTH + columnIndex;
          const loc = i + MMU_OFFSETS.shift;
          return (
            <div
              style={style}
              className={cx(
                CSS.outputCell,
                props.highlightClasses[loc],
                MEMLOC_CSS[loc],
                loc === props.focus && "active"
              )}
            >
              {hex2(props.mem[i] || 0)}
            </div>
          );
        }}
      </FixedSizeGrid>
    </div>
  );
}

export default function Mmu(props: { fd: FundudeWasm }) {
  const [focus, setFocus] = React.useState(0);
  const cpu = props.fd.cpu();
  return (
    <div className={CSS.root}>
      <div className={CSS.controls}>
        {MMU_OFFSETS.segments.map(segment => (
          <div key={segment.name} className={REGION_CSS[segment.name]}>
            <div>{segment.name}</div>
            <button onClick={() => setFocus(segment.start)}>
              {hex4(segment.start)}
            </button>
            <button onClick={() => setFocus(segment.end)}>
              {hex4(segment.end)}
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
        mem={() => props.fd.mmu()}
        focus={focus}
        highlightClasses={{
          [cpu.HL()]: CSS.hl,
          [cpu.SP()]: CSS.sp
        }}
      />
    </div>
  );
}
