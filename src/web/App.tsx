import React, { useState } from "react";
import { style } from "typestyle";
import FD from "../wasm/react";
import Display from "./Display";
import CartSelect from "./CartSelect";
import { BOOTLOADER } from "./data";
import Debug from "./Debug";
//@ts-ignore
import Logo from "./logo.svg";

import useEvent from "react-use/lib/useEvent";

const CSS = {
  root: style({
    overflow: "hidden",
    width: "100vw",
    height: "100vh",
    display: "flex",
    justifyContent: "center"
  }),

  app: style({
    marginTop: "4px",
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

  title: style({
    position: "relative",
    textTransform: "uppercase",
    fontFamily: "'Gill Sans', sans-serif",
    fontWeight: "bold",
    fontStyle: "italic",
    letterSpacing: "-2px",
    color: "white"
  }),

  titleText: style({
    color: "transparent"
  }),

  logo: style({
    position: "absolute",
    top: "20%",
    height: "59%",
    pointerEvents: "none"
  }),

  controls: style({
    height: "300px"
  })
};

export function App(props: { debug?: boolean }) {
  const { fd } = React.useContext(FD.Context);

  return (
    <div className={CSS.app}>
      <CartSelect startName="Bootloader" debug={props.debug} />
      <div className={CSS.shell}>
        <div className={CSS.displayWrapper}>
          <Display pixels={fd.display()} signal={fd.changed} scale={2} />
          <h1 className={CSS.title}>
            <Logo className={CSS.logo} />
            <span className={CSS.titleText}>FUN DUDE</span>
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
        <App debug={props.debug} />
        {debug && <Debug.Right />}
      </div>
    </FD.Provider>
  );
}
