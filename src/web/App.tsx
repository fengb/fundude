import React from "react";
import { style } from "typestyle";
import FD from "../wasm/react";
import Display from "./Display";
import CartSelect from "./CartSelect";
import Controller from "./Controller";
import Toaster from "./Toaster";
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

  display: style({
    maxWidth: "100vw"
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

  titleSymbol: style({
    fontSize: "0.5em",
    verticalAlign: "middle"
  }),

  logo: style({
    position: "absolute",
    top: "20%",
    height: "59%",
    pointerEvents: "none"
  }),

  controls: style({
    height: "300px",
    width: "324px",
    margin: "0 auto",
    display: "flex",
    justifyContent: "center",
    alignItems: "center"
  })
};

export function App(props: { debug?: boolean }) {
  const { fd } = React.useContext(FD.Context);

  return (
    <div className={CSS.app}>
      <CartSelect startName="Bootloader" debug={props.debug} />
      <div className={CSS.shell}>
        <div className={CSS.displayWrapper}>
          <Display
            className={CSS.display}
            pixels={fd.display()}
            signal={fd.changed}
            scale={2}
          />
          <h1 className={CSS.title}>
            <Logo className={CSS.logo} />
            <span className={CSS.titleText}>
              FUN
              <i className={CSS.titleSymbol}>&#10012;</i>
              DUDE
            </span>
          </h1>
        </div>
        <div className={CSS.controls}>
          <Controller fd={fd} />
        </div>
      </div>
    </div>
  );
}

function Shell(props: { debug?: boolean }) {
  const [debug, setDebug] = React.useState(
    window.location.hash.includes("debug")
  );
  useEvent("hashchange", () =>
    setDebug(window.location.hash.includes("debug"))
  );
  const toaster = React.useContext(Toaster.Context);

  return (
    <FD.Provider
      bootCart={BOOTLOADER}
      autoBoot={!debug}
      onError={e => toaster.add({ title: "Fatal", body: e.message || e })}
    >
      <Toaster.ShowAll />
      <div className={CSS.root}>
        {debug && <Debug.Left />}
        <App debug={debug} />
        {debug && <Debug.Right />}
      </div>
    </FD.Provider>
  );
}

export default function() {
  return (
    <Toaster.Provider>
      <Shell />
    </Toaster.Provider>
  );
}
