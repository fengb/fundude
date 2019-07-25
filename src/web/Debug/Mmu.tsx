import React from "react";
import { style } from "typestyle";
import cx from "classnames";
import { FixedSizeGrid } from "react-window";

import map from "lodash/map";

import FundudeWasm, { PtrArray, MMU_OFFSETS } from "../../wasm";
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

  cell: style({
    fontFamily: "monospace",
    textAlign: "center",

    $nest: {
      "&.active": {
        boxShadow: "inset 0 0 0 1px black"
      }
    }
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
for (const [key, tuple] of Object.entries(MMU_OFFSETS.segments)) {
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
  const gridRef = React.createRef<FixedSizeGrid>();

  React.useEffect(() => {
    const i = props.focus - MMU_OFFSETS.shift;
    gridRef.current &&
      gridRef.current.scrollToItem({
        columnIndex: i % WIDTH,
        rowIndex: i / WIDTH
      });
  }, [gridRef.current, props.focus]);

  return (
    <FixedSizeGrid
      ref={gridRef}
      height={800}
      width={430}
      columnCount={WIDTH}
      rowCount={props.mem.length() / WIDTH}
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
              CSS.cell,
              props.highlightClasses[loc],
              MEMLOC_CSS[loc],
              loc === props.focus && "active"
            )}
          >
            {hex2(props.mem.base[i] || 0)}
          </div>
        );
      }}
    </FixedSizeGrid>
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
            <button onClick={() => setFocus(tuple[0])}>{hex4(tuple[0])}</button>
            <button onClick={() => setFocus(tuple[1])}>{hex4(tuple[1])}</button>
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
