import React, { useState } from "react";
import { style } from "typestyle";
import FD from "../wasm/react";
import Display from "./Display";
import CartSelect from "./CartSelect";
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
    margin: "8px 50px",
    display: "flex",
    flexDirection: "column",
    alignItems: "center"
  }),

  shell: style({
    padding: "20px 16px",
    background: "#f5f5dc",
    boxShadow: "inset 0 0 0 4px rgba(32, 32, 32, 0.5)",
    borderRadius: "8px 8px 40px 40px"
  }),

  displayWrapper: style({
    backgroundColor: "#606060",
    padding: "20px 50px 0",
    borderRadius: "8px"
  }),

  logo: style({
    textTransform: "uppercase",
    fontFamily: "'Gill Sans', sans-serif",
    fontWeight: "bold",
    fontStyle: "italic",
    letterSpacing: "-2px",
    color: "white"
  }),

  logoInvert: style({
    fontSize: "0.6em",
    verticalAlign: "4px",
    color: "#606060",
    background: "white",
    padding: "0 4px 0 2px"
  }),

  controls: style({
    height: "300px"
  })
};

export function App() {
  const { fd } = React.useContext(FD.Context);

  return (
    <div className={CSS.app}>
      <CartSelect startName="Bootloader" />
      <div className={CSS.shell}>
        <div className={CSS.displayWrapper}>
          <Display pixels={fd.display()} signal={fd.changed} scale={2} />
          <h1 className={CSS.logo}>
            Fun dude <span className={CSS.logoInvert}>!</span>
          </h1>
        </div>
        <div className={CSS.controls} />
      </div>
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
