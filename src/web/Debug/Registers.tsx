import React from "react";
import { style } from "typestyle";
import FundudeWasm from "../../wasm";

const CSS = {
  root: style({
    display: "flex",
    textAlign: "center",
    fontFamily: "monospace"
  }),
  child: style({
    padding: "0 6px"
  })
};

function hexup(array: Uint8Array, left: number) {
  const right = left + 1;
  return (array[left] + (array[right] << 8))
    .toString(16)
    .toUpperCase()
    .padStart(4, "0");
}

export default function Registers({ fd }: { fd: FundudeWasm }) {
  return (
    <dl className={CSS.root}>
      <div className={CSS.child}>
        <dt>AF</dt>
        <dd>{hexup(fd.registers, 0)}</dd>
      </div>
      <div className={CSS.child}>
        <dt>BC</dt>
        <dd>{hexup(fd.registers, 2)}</dd>
      </div>
      <div className={CSS.child}>
        <dt>DE</dt>
        <dd>{hexup(fd.registers, 4)}</dd>
      </div>
      <div className={CSS.child}>
        <dt>HL</dt>
        <dd>{hexup(fd.registers, 6)}</dd>
      </div>
      <div className={CSS.child}>
        <dt>SP</dt>
        <dd>{hexup(fd.registers, 8)}</dd>
      </div>
      <div className={CSS.child}>
        <dt>PC</dt>
        <dd>{hexup(fd.registers, 10)}</dd>
      </div>
    </dl>
  );
}
