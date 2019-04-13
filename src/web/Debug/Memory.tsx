import React from "react";
import { times } from "lodash";
import { style } from "typestyle";
import FundudeWasm from "../../wasm";

const CSS = {
  root: style({
    display: "flex",
    flexDirection: "column",
    height: "100%",
    maxHeight: "100vh"
  }),
  wrapper: style({
    overflow: "auto"
  }),
  table: style({
    fontFamily: "monospace",
    borderCollapse: "collapse"
  }),
  zebra: style({
    background: "lightgrey"
  }),
  cell: style({
    padding: "0 4px"
  })
};

const WIDTH = 16;
const ZEBRA_SIZE = 4;

function MemorySegment(props: { mem: Uint8Array; offset: number }) {
  const height = props.mem.length / WIDTH;
  return (
    <table className={CSS.table}>
      <colgroup>
        <col />
        {times(WIDTH / ZEBRA_SIZE, n => (
          <col
            key={n}
            className={n % 2 == 0 ? CSS.zebra : ""}
            span={ZEBRA_SIZE}
          />
        ))}
      </colgroup>
      <tbody>
        {times(height, row => (
          <tr key={row}>
            <th>
              $
              {(props.offset + row * WIDTH)
                .toString(16)
                .padStart(4, "0")
                .toUpperCase()}
            </th>
            {times(WIDTH, col => (
              <td key={col} className={CSS.cell}>
                {props.mem[row * WIDTH + col]
                  .toString(16)
                  .padStart(2, "0")
                  .toUpperCase()}
              </td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export default function Memory(props: { fd: FundudeWasm }) {
  const [segment, setSegment] = React.useState(
    "ram" as keyof FundudeWasm["memory"]
  );
  const mem = props.fd.memory[segment];
  return (
    <div className={CSS.root}>
      <div>
        <button onClick={() => setSegment("vram")}>VRAM</button>
        <button onClick={() => setSegment("ram")}>RAM</button>
        <button onClick={() => setSegment("raw")}>RAW</button>
      </div>
      <div className={CSS.wrapper}>
        <MemorySegment mem={mem} offset={mem.offset} />
      </div>
    </div>
  );
}
