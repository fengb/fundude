import React from "react";
import * as DI from "./DI";
import Display from "./Display";
import CartList from "./CartList";
import FundudeWasm from "./wasm";
import { EMPTY, BOOTLOADER } from "./data";
import Disassembler from "./Disassembler";

export function App() {
  const { cart } = React.useContext(DI.Context);
  const [fd, setFd] = React.useState<FundudeWasm>();
  React.useEffect(() => {
    FundudeWasm.boot(cart.value).then(setFd);
  }, []);

  return (
    <div style={{ width: "100vw", height: "100vh", display: "flex" }}>
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
