import React from "react";
import { style } from "typestyle";
import FD from "../../wasm/react";
import Display from "../Display";
import Disassembler from "./Disassembler";
import Cpu from "./Cpu";
import Mmu from "./Mmu";

const CSS = {
  controls: style({
    display: "flex",
    justifyContent: "space-between"
  })
};

export function Left() {
  const { fd, run, pause } = React.useContext(FD.Context);
  return (
    <div>
      <div className={CSS.controls}>
        <button onClick={run}>Run</button>
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
    <div>
      <Display pixels={fd.background()} />
      {/* <Display pixels={fd.window()} /> */}
      {/* <Display pixels={fd.tileData()} /> */}
      <Mmu fd={fd} />
    </div>
  );
}

export default { Left, Right };
