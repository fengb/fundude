import React from "react";
import Display from "./Display";
import CartList from "./CartList";
import FundudeWasm from "./wasm";
import { EMPTY } from "./data";
import Disassembler from "./Disassembler";

export default function App() {
  const [fd, setFd] = React.useState<FundudeWasm>();
  React.useEffect(() => {
    FundudeWasm.boot(EMPTY).then(setFd);
  }, []);

  return (
    <div style={{ width: "100vw", height: "100vh", display: "flex" }}>
      <CartList extra={{ "-empty-": EMPTY }} />
      {fd && <Display fundude={fd} />}
      <Disassembler cart={EMPTY} />
    </div>
  );
}