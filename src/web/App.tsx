import React from "react";
import { style } from "typestyle";
import * as FD from "./Context/FD";
import Display from "./Display";
import CartList from "./CartList";
import FundudeWasm from "./wasm";
import { EMPTY, BOOTLOADER } from "./data";
import Disassembler from "./Debug/Disassembler";
import Registers from "./Debug/Registers";

const CSS = {
  root: style({
    width: "100vw",
    height: "100vh",
    display: "flex"
  })
};

export function App() {
  const fd = React.useContext(FD.Context);

  return (
    <div className={CSS.root}>
      <CartList extra={{ "-empty-": EMPTY, bootloader: BOOTLOADER }} />
      {fd && (
        <div>
          <Display fundude={fd.fd} />
          <button onClick={() => fd.fd.step()}>Step</button>
          <Registers fd={fd.fd} />
        </div>
      )}
      {fd && <Disassembler cart={fd.cart} />}
    </div>
  );
}

export default function() {
  return (
    <FD.Provider bootCart={EMPTY}>
      <App />
    </FD.Provider>
  );
}
