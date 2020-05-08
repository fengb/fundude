import React from "react";

import FD from "../wasm/react";
import nano from "./nano";

import Display from "./Display";
import CartSelect from "./CartSelect";
import Controller from "./Controller";
import { BOOTLOADER } from "./data";

const LazyDebug = {
  Left: React.lazy(() =>
    import("./Debug").then((mod) => ({ default: mod.Left }))
  ),
  Right: React.lazy(() =>
    import("./Debug").then((mod) => ({ default: mod.Right }))
  ),
};

//@ts-ignore
import logo from "data-url:./logo.svg";

const CSS = {
  root: nano.rule({
    overflow: "hidden",
    width: "100vw",
    height: "100vh",
    display: "flex",
    justifyContent: "center",
  }),

  app: nano.rule({
    marginTop: "4px",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
  }),

  shell: nano.rule({
    padding: "20px 16px",
    background: "#f5f5dc",
    boxShadow: "inset 0 0 0 4px rgba(32, 32, 32, 0.5)",
    borderRadius: "8px 8px 40px 40px",
  }),

  displayWrapper: nano.rule({
    backgroundColor: "#606060",
    padding: "20px 50px 0",
    borderRadius: "8px",
  }),

  display: nano.rule({
    maxWidth: "100vw",
    background: "#b1c062",
  }),

  title: nano.rule({
    position: "relative",
    textTransform: "uppercase",
    fontFamily: "'Gill Sans', Verdana, sans-serif",
    fontWeight: "bold",
    fontStyle: "italic",
    letterSpacing: "-0.06em",
    color: "transparent",
  }),

  titleSymbol: nano.rule({
    fontSize: "0.5em",
    verticalAlign: "middle",
  }),

  logo: nano.rule({
    filter: "invert(1)",
    position: "absolute",
    top: "20%",
    width: "auto",
    height: "59%",
    pointerEvents: "none",
  }),

  controls: nano.rule({
    height: "300px",
    width: "324px",
    margin: "0 auto",
  }),
};

export function App(props: { debug?: boolean }) {
  const { fd } = React.useContext(FD.Context);

  return (
    <div className={CSS.app}>
      <CartSelect startName="{insert cart}" debug={props.debug} />
      <div className={CSS.shell}>
        <div className={CSS.displayWrapper}>
          <Display
            className={CSS.display}
            pixels={() => fd.screen()}
            signal={fd.changed}
            scale={2}
            blend
          />
          <h1 className={CSS.title}>
            <img className={CSS.logo} src={logo} />
            FUN
            <i className={CSS.titleSymbol}>&#10012;</i>
            DUDE
          </h1>
        </div>
        <div className={CSS.controls}>
          <Controller fd={fd} />
        </div>
      </div>
    </div>
  );
}

export default function (props: { debug?: boolean }) {
  return (
    <FD.Provider bootCart={BOOTLOADER} autoBoot={!props.debug}>
      <div className={CSS.root}>
        <React.Suspense fallback={<div />}>
          {props.debug && <LazyDebug.Left />}
        </React.Suspense>
        <App debug={props.debug} />
        <React.Suspense fallback={<div />}>
          {props.debug && <LazyDebug.Right />}
        </React.Suspense>
      </div>
    </FD.Provider>
  );
}
