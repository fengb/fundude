import React from "react";
import { style } from "typestyle";
import FundudeWasm from "../../wasm";
import { hex4 } from "./util";

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

export default function Registers({ fd }: { fd: FundudeWasm }) {
  return (
    <dl className={CSS.root}>
      <div className={CSS.child}>
        <dt>AF</dt>
        <dd>{hex4(fd.registers.AF())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>BC</dt>
        <dd>{hex4(fd.registers.BC())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>DE</dt>
        <dd>{hex4(fd.registers.DE())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>HL</dt>
        <dd>{hex4(fd.registers.HL())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>SP</dt>
        <dd>{hex4(fd.registers.SP())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>PC</dt>
        <dd>{hex4(fd.registers.PC())}</dd>
      </div>
    </dl>
  );
}
