import React from "react";
import { style } from "typestyle";
import FD from "../../wasm/react";
import Display from "../Display";
import Disassembler from "./Disassembler";
import Cpu from "./Cpu";
import Mmu from "./Mmu";

const CSS = {
  base: style({
    display: "flex",
    flexDirection: "column"
  }),

  controls: style({
    display: "flex",
    justifyContent: "space-between"
  })
};

export function Left() {
  const { fd, run, pause } = React.useContext(FD.Context);
  return (
    <div className={CSS.base}>
      <div className={CSS.controls}>
        <div>
          <button onClick={run}>&#9658;</button>
          <button onClick={pause}>&#10073;&#10073;</button>
        </div>
        <div>
          <button onClick={() => fd.step() && pause()}>Step</button>
          <button onClick={() => fd.stepFrame() && pause()}>Frame</button>
          <button onClick={() => fd.stepFrame(60) && pause()}>Second</button>
        </div>
      </div>
      <Cpu reg={fd.cpu()} />
      <Disassembler fd={fd} />
    </div>
  );
}

export function Right() {
  const { fd } = React.useContext(FD.Context);
  return (
    <div className={CSS.base}>
      <div>
        <Display pixels={fd.background()} />
        {/* <Display pixels={fd.window()} /> */}
        {/* <Display pixels={fd.tileData()} /> */}
      </div>
      <Mmu fd={fd} />
    </div>
  );
}

export default { Left, Right };
