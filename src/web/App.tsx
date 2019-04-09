import React from "react";
import { style } from "typestyle";
import * as DI from "./DI";
import Display from "./Display";
import CartList from "./CartList";
import FundudeWasm from "./wasm";
import { EMPTY, BOOTLOADER } from "./data";
import Disassembler from "./Disassembler";

const CSS = {
  root: style({
    width: "100vw",
    height: "100vh",
    display: "flex"
  })
};

export function App() {
  const { cart } = React.useContext(DI.Context);
  const [fd, setFd] = React.useState<FundudeWasm>();
  React.useEffect(() => {
    FundudeWasm.boot(cart.value).then(setFd);
  }, []);

  return (
    <div className={CSS.root}>
      <CartList extra={{ "-empty-": EMPTY, bootloader: BOOTLOADER }} />
      {fd && <Display fundude={fd} />}
      <Disassembler cart={cart.value} />
    </div>
  );
}

export default function() {
  return (
    <DI.Container>
      <App />
    </DI.Container>
  );
}
