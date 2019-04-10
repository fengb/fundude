import React from "react";
import { style } from "typestyle";
import useEvent from "react-use/lib/useEvent";
import FundudeWasm from "../wasm";

const CSS = {
  root: style({
    display: "flex",
    textAlign: "center"
  }),
  child: style({
    padding: "0 4px"
  })
};

export default function Registers({ fd }: { fd: FundudeWasm }) {
  const [refresh, setRefresh] = React.useState();
  useEvent("programCounter", setRefresh, fd);

  return (
    <dl className={CSS.root}>
      <div className={CSS.child}>
        <dt>AF</dt>
        <dd>
          {fd.registers[0].toString(16)}
          {fd.registers[1].toString(16)}
        </dd>
      </div>
      <div className={CSS.child}>
        <dt>BC</dt>
        <dd>
          {fd.registers[2].toString(16)}
          {fd.registers[3].toString(16)}
        </dd>
      </div>
      <div className={CSS.child}>
        <dt>DE</dt>
        <dd>
          {fd.registers[4].toString(16)}
          {fd.registers[5].toString(16)}
        </dd>
      </div>
      <div className={CSS.child}>
        <dt>HL</dt>
        <dd>
          {fd.registers[6].toString(16)}
          {fd.registers[7].toString(16)}
        </dd>
      </div>
      <div className={CSS.child}>
        <dt>SP</dt>
        <dd>
          {fd.registers[8].toString(16)}
          {fd.registers[9].toString(16)}
        </dd>
      </div>
      <div className={CSS.child}>
        <dt>PC</dt>
        <dd>
          {fd.registers[10].toString(16)}
          {fd.registers[11].toString(16)}
        </dd>
      </div>
    </dl>
  );
}
