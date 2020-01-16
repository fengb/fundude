import React from "react";

import nano from "../nano";

import FD from "../../wasm/react";
import Display from "../Display";
import Disassembler from "./Disassembler";
import Cpu from "./Cpu";
import Mmu from "./Mmu";
import FundudeWasm from "../../wasm";

const CSS = {
  base: nano.rule({
    display: "flex",
    flexDirection: "column",
    position: "relative",
    margin: "0 50px"
  }),

  controls: nano.rule({
    display: "flex",
    justifyContent: "space-between"
  }),

  displays: nano.rule({
    position: "relative",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "flex-end"
  }),

  displayPatterns: nano.rule({
    position: "absolute",
    top: 0,
    left: "100%"
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
          <button onClick={() => fd.stepMs(16.75) && pause()}>Frame</button>
          <button onClick={() => fd.stepMs(1000) && pause()}>Sec</button>
          <button onClick={timed(() => fd.stepMs(250000) && pause())}>
            &#9992;
          </button>
        </div>
      </div>
      <Cpu reg={() => fd.cpu()} />
      <Disassembler fd={fd} />
    </div>
  );
}

function Displays(props: { fd: FundudeWasm }) {
  const { fd } = React.useContext(FD.Context);

  const [_, setRerender] = React.useState();
  React.useEffect(() => {
    function forceRender() {
      setRerender(prev => !prev);
    }
    fd.changed.add(forceRender);
    return () => fd.changed.remove(forceRender);
  }, []);

  const mmu = fd.mmu();

  const scx = mmu[0xff43 - 0x8000];
  const scy = mmu[0xff42 - 0x8000];

  return (
    <React.Fragment>
      {/* TODO: convert to tile display */}
      <Display
        className={CSS.displayPatterns}
        pixels={() => fd.patterns()}
        viewports={[]}
        gridColor="lightgray"
      />
      <Display
        pixels={() => fd.sprites()}
        viewports={[[8, 16]]}
        gridColor="lightgray"
      />
      <div className={CSS.displays}>
        <Display
          pixels={() => fd.background()}
          viewports={[
            [scx, scy],
            [scx - 256, scy],
            [scx, scy - 256],
            [scx - 256, scy - 256]
          ]}
          gridColor="lightgray"
        />
        <Display
          pixels={() => fd.window()}
          gridColor="lightgray"
          viewports={[]}
        />
      </div>
    </React.Fragment>
  );
}

export function Right() {
  const { fd } = React.useContext(FD.Context);

  return (
    <div className={CSS.base}>
      <Displays fd={fd} />
      <Mmu fd={fd} />
    </div>
  );
}

export default { Left, Right };
