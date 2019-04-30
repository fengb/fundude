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
  })
};

const INT16_MAX = 2 ** 16 / 2 - 1;

export function App() {
  const { fd } = React.useContext(FD.Context);

  function TURBO() {
    const start = Date.now();
    const rendered = fd.stepFrame(INT16_MAX);
    console.log(
      "TURBO -- rt:",
      (Date.now() - start) / 1000,
      "gb:",
      rendered / 60
    );
  }

  return (
    <div className={CSS.root}>
      <CartList extra={{ bootloader: BOOTLOADER }} />
      <div>
        <Display pixels={fd.display()} />
        <Display pixels={fd.background()} />
        <Display pixels={fd.window()} />
        <Display pixels={fd.tileData()} />
        <button onClick={() => fd.step()}>Cycle</button>
        <button onClick={() => fd.stepFrame()}>Frame</button>
        <button onClick={() => fd.stepFrame(60)}>Second</button>
        <button onClick={TURBO}>TURBO</button>
        <Cpu reg={fd.cpu()} />
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
