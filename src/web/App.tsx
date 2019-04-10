import React from "react";
import { style } from "typestyle";
import * as DI from "./DI";
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
  const { cart } = React.useContext(DI.Context);
  const [fd, setFd] = React.useState<FundudeWasm>();
  React.useEffect(() => {
    FundudeWasm.boot(cart.value).then(fd => {
      setFd(fd);
      Object.assign(window, { fd });
    });
  }, []);

  return (
    <div className={CSS.root}>
      <CartList extra={{ "-empty-": EMPTY, bootloader: BOOTLOADER }} />
      {fd && (
        <div>
          <Display fundude={fd} />
          <button onClick={() => fd.step()}>Step</button>
          <Registers fd={fd} />
        </div>
      )}
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
