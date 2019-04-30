import React from "react";
import { style } from "typestyle";
import FD from "../wasm/react";
import Display from "./Display";
import CartList from "./CartList";
import { BOOTLOADER } from "./data";
import Disassembler from "./Debug/Disassembler";
import Cpu from "./Debug/Cpu";
import Mmu from "./Debug/Mmu";

const CSS = {
  root: style({
    width: "100vw",
    height: "100vh",
    display: "flex"
  }),

  controls: style({
    display: "flex",
    justifyContent: "space-between"
  })
};

export function App() {
  const { fd, run, stop } = React.useContext(FD.Context);

  return (
    <div className={CSS.root}>
      <CartList extra={{ bootloader: BOOTLOADER }} />
      <div>
        <Display pixels={fd.display()} signal={fd.changed} />
        <div className={CSS.controls}>
          <button onClick={run}>Run</button>
          <div>
            <button onClick={() => fd.step() && stop()}>Step</button>
            <button onClick={() => fd.stepFrame() && stop()}>Frame</button>
            <button onClick={() => fd.stepFrame(60) && stop()}>Second</button>
          </div>
        </div>
        <Cpu reg={fd.cpu()} />
        <Display pixels={fd.background()} />
        <Display pixels={fd.window()} />
        <Display pixels={fd.tileData()} />
      </div>
      <Disassembler fd={fd} />
      <Mmu fd={fd} />
    </div>
  );
}

export default function() {
  return (
    <FD.Provider bootCart={BOOTLOADER}>
      <App />
    </FD.Provider>
  );
}
