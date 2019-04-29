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

export default function Cpu(props: {
  reg: ReturnType<FundudeWasm["cpu"]>;
}) {
  return (
    <dl className={CSS.root}>
      <div className={CSS.child}>
        <dt>AF</dt>
        <dd>{hex4(props.reg.AF())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>BC</dt>
        <dd>{hex4(props.reg.BC())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>DE</dt>
        <dd>{hex4(props.reg.DE())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>HL</dt>
        <dd>{hex4(props.reg.HL())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>SP</dt>
        <dd>{hex4(props.reg.SP())}</dd>
      </div>
      <div className={CSS.child}>
        <dt>PC</dt>
        <dd>{hex4(props.reg.PC())}</dd>
      </div>
    </dl>
  );
}
