import React from "react";
import cx from "classnames";

import nano from "./nano";
import { mapObject } from "./smalldash";
import { readAsArray } from "./promise";

import FD from "../wasm/react";

import ROMS from "../roms";
import DEBUG_ROMS from "../roms/debug";

const CSS = {
  root: nano.rule({
    position: "relative",
    zIndex: 1,
    width: "350px",
    height: "18px"
  }),

  toggler: nano.rule({
    position: "absolute",
    zIndex: 1,
    boxSizing: "content-box",
    height: "14px",
    width: "100%",
    bottom: 0,
    border: "none",
    padding: 0,
    background: "#d9d9d9",
    borderRadius: "2px 2px 0 0",
    cursor: "pointer",
    textAlign: "center",
    transition: "200ms ease-in-out padding-top",

    "&:hover": {
      paddingTop: "4px"
    }
  }),

  selector: nano.rule({
    position: "absolute",
    overflow: "hidden",
    top: "100%",
    width: "100%",
    background: "#ffffffd0",
    transition: "300ms ease-in-out height",
    padding: "0 10px",
    height: "0",

    "&.active": {
      height: "350px"
    }
  }),

  selectorList: nano.rule({
    display: "flex",
    flexDirection: "column"
  }),

  backdrop: nano.rule({
    position: "fixed",
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    background: "#000000",
    opacity: 0,
    transition: "300ms ease-in opacity",
    pointerEvents: "none",

    "&.active": {
      pointerEvents: "initial",
      opacity: 0.8
    }
  })
};

export default function CartSelect(props: {
  startName: string;
  debug?: boolean;
}) {
  const { fd } = React.useContext(FD.Context);
  const [choosing, setChoosing] = React.useState(false);
  const [name, setName] = React.useState(props.startName);

  const selectCart = React.useCallback(
    (name: string, data: Uint8Array) => {
      setChoosing(false);
      fd.init(data);
      setName(name);
    },
    [fd]
  );

  type LinkClicked = React.MouseEventHandler<HTMLAnchorElement>;
  const downloadCart = React.useCallback<LinkClicked>(async event => {
    event.preventDefault();
    const link = event.currentTarget;
    const resp = await fetch(link.href);
    if (!resp.ok) {
      throw resp;
    }

    const data = new Uint8Array(await resp.arrayBuffer());
    selectCart(link.text, data);
  }, []);

  type FileChanged = React.ChangeEventHandler<HTMLInputElement>;
  const onFile = React.useCallback<FileChanged>(async event => {
    const file = event.currentTarget.files[0] as File;
    const data = new Uint8Array(await readAsArray(file));
    selectCart(file.name, data);
  }, []);

  const carts = props.debug ? DEBUG_ROMS.blargg : ROMS;

  return (
    <div className={CSS.root}>
      <button className={CSS.toggler} onClick={() => setChoosing(!choosing)}>
        {name}
      </button>

      <div
        className={cx(CSS.backdrop, choosing && "active")}
        onClick={() => setChoosing(false)}
      />

      <div className={cx(CSS.selector, choosing && "active")}>
        <div className={cx(CSS.selectorList, choosing && "active")}>
          {mapObject(carts, (value, name) => (
            <a key={name} href={value} onClick={downloadCart}>
              {name}
            </a>
          ))}
        </div>
        <label>
          <input
            type="file"
            onChange={onFile}
            onClick={event => (event.currentTarget.value = "")}
          />
        </label>
      </div>
    </div>
  );
}
