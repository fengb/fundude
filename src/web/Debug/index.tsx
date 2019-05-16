import React from "react";
import { style } from "typestyle";
import FD from "../../wasm/react";
import Display from "../Display";
import Disassembler from "./Disassembler";
import Cpu from "./Cpu";
import Mmu from "./Mmu";

const TURBO_FRAMES = 60 * 250;

const CSS = {
  base: style({
    display: "flex",
    flexDirection: "column",
    margin: "0 50px"
  }),

  controls: style({
    display: "flex",
    justifyContent: "space-between"
  }),

  displays: style({
    position: "relative",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "flex-end"
  }),

  displaySprites: style({
    position: "absolute",
    top: 0,
    right: 0
  })
};

function timed<T, R>(fn: (T) => R): (T) => R {
  return function(t: T) {
    const start = Date.now();
    const val = fn(t);
    console.log(`${(Date.now() - start) / 1000}s realtime -- 250s ingame`);
    return val;
  };
}

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
          <button onClick={() => fd.stepFrame(60) && pause()}>Sec</button>
          <button onClick={timed(() => fd.stepFrame(TURBO_FRAMES) && pause())}>
            &#9992;
          </button>
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
      <div className={CSS.displays}>
        <Display pixels={fd.background()} />
        <Display className={CSS.displaySprites} pixels={fd.sprites()} />
        <Display pixels={fd.patterns()} />
      </div>
      <Mmu fd={fd} />
    </div>
  );
}

export default { Left, Right };
