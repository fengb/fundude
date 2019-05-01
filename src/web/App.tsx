import React, { useState } from "react";
import { style } from "typestyle";
import FD from "../wasm/react";
import Display from "./Display";
import CartList from "./CartList";
import { BOOTLOADER } from "./data";
import Debug from "./Debug";

import useEvent from "react-use/lib/useEvent";

const CSS = {
  root: style({
    width: "100vw",
    height: "100vh",
    display: "flex",
    justifyContent: "center"
  }),

  app: style({
    margin: "0 50px"
  })
};

export function App() {
  const { fd } = React.useContext(FD.Context);

  return (
    <div className={CSS.app}>
      <CartList extra={{ bootloader: BOOTLOADER }} />
      <Display pixels={fd.display()} signal={fd.changed} />
    </div>
  );
}

export default function(props: { debug?: boolean }) {
  const [debug, setDebug] = useState(props.debug);
  useEvent(
    "hashchange",
    () => setDebug(window.location.hash.includes("debug")),
    window
  );
  return (
    <FD.Provider bootCart={BOOTLOADER}>
      <div className={CSS.root}>
        {debug && <Debug.Left />}
        <App />
        {debug && <Debug.Right />}
      </div>
    </FD.Provider>
  );
}
