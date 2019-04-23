import React from "react";
import { style } from "typestyle";
import FD from "../wasm/react";
import Display from "./Display";
import CartList from "./CartList";
import { BOOTLOADER } from "./data";
import Disassembler from "./Debug/Disassembler";
import Registers from "./Debug/Registers";
import Memory from "./Debug/Memory";

const CSS = {
  root: style({
    width: "100vw",
    height: "100vh",
    display: "flex"
  })
};

export function App() {
  const { fd } = React.useContext(FD.Context);

  return (
    <div className={CSS.root}>
      <CartList extra={{ bootloader: BOOTLOADER }} />
      <div>
        <Display pixels={fd.display} width={160} height={144} />
        <Display pixels={fd.background} width={256} height={256} />
        <Display pixels={fd.window} width={256} height={256} />
        <button onClick={() => fd.step()}>Step</button>
        <button onClick={() => fd.stepFrame()}>Step Frame</button>
        <button onClick={() => fd.stepFrame(60)}>Step Second</button>
        <Registers fd={fd} />
      </div>
      <Disassembler fd={fd} />
      <Memory fd={fd} />
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
