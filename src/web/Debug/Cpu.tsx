import React from "react";

import nano from "../nano";
import { hex4 } from "./util";

import FundudeWasm from "../../wasm";

const CSS = {
  root: nano.rule({
    display: "flex",
    textAlign: "center",
    fontFamily: "monospace",
    justifyContent: "space-between"
  })
};

export default function Cpu(props: {
  reg: () => ReturnType<FundudeWasm["cpu"]>;
}) {
  const reg = props.reg();
  return (
    <dl className={CSS.root}>
      <div>
        <dt>AF</dt>
        <dd>{hex4(reg.AF())}</dd>
      </div>
      <div>
        <dt>BC</dt>
        <dd>{hex4(reg.BC())}</dd>
      </div>
      <div>
        <dt>DE</dt>
        <dd>{hex4(reg.DE())}</dd>
      </div>
      <div>
        <dt>HL</dt>
        <dd>{hex4(reg.HL())}</dd>
      </div>
      <div>
        <dt>SP</dt>
        <dd>{hex4(reg.SP())}</dd>
      </div>
      <div>
        <dt>PC</dt>
        <dd>{hex4(reg.PC())}</dd>
      </div>
    </dl>
  );
}
