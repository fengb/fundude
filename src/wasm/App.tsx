import React from "react";
import Display from "./Display";
import CartList from "./CartList";
import FundudeWasm from "./core";
import { EMPTY } from "./data";

export default function App() {
  const [fd, setFd] = React.useState<FundudeWasm>();
  React.useEffect(() => {
    FundudeWasm.boot(EMPTY).then(setFd);
  }, []);

  return (
    <div>
      <CartList />
      {fd && <Display fundude={fd} />}
    </div>
  );
}
