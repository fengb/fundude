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

function hexup(n: number) {
  return n
    .toString(16)
    .toUpperCase()
    .padStart(4, "0");
}

export default function Registers({ fd }: { fd: FundudeWasm }) {
  return (
    <dl className={CSS.root}>
      <div className={CSS.child}>
        <dt>AF</dt>
        <dd>{hexup(fd.registers.AF())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>BC</dt>
        <dd>{hexup(fd.registers.BC())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>DE</dt>
        <dd>{hexup(fd.registers.DE())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>HL</dt>
        <dd>{hexup(fd.registers.HL())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>SP</dt>
        <dd>{hexup(fd.registers.SP())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>PC</dt>
        <dd>{hexup(fd.registers.PC())}</dd>
      </div>
    </dl>
  );
}
