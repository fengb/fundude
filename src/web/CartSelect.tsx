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
    textAlign: "center"
  }),

  toggler: nano.rule({
    position: "relative",
    display: "block",
    zIndex: 1,
    font: "14px monospace",
    width: "100%",
    border: "none",
    padding: "0 10px",
    background: "#d9d9d9",
    borderRadius: "3px 3px 0 0",
    overflow: "hidden",
    whiteSpace: "nowrap",
    textOverflow: "ellipsis"
  }),

  selector: nano.rule({
    position: "absolute",
    overflow: "hidden",
    top: "100%",
    width: "100%",
    background: "rgba(255, 255, 255, 0.8)",
    transition: "300ms ease-in-out height",
    padding: "0 10px",
    height: "0",
    borderRadius: "0 0 3px 3px",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",

    "&.active": {
      height: "350px"
    }
  }),

  selectorList: nano.rule({
    font: "14px monospace",
    flex: 1,
    overflow: "hidden",
  }),

  backdrop: nano.rule({
    position: "fixed",
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    background: "#000000",
    opacity: 0,
    transition: "300ms ease-in-out opacity",
    pointerEvents: "none",

    "&.active": {
      pointerEvents: "initial",
      opacity: 0.8
    }
  }),

  prompt: nano.rule({
    marginTop: "12px",

    "&:before, &:after": {
      padding: "0 4px",
      content: "'—'"
    }
  }),

  upload: nano.rule({
    display: "inline-block",
    cursor: "pointer",
    background: "white",
    border: "1px solid black",
    borderRadius: "4px",
    padding: "4px 20px",
    marginBottom: "10px"
  }),

  hidden: nano.rule({
    display: "none"
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
        <h3 className={CSS.prompt}>try one of these games</h3>
        <div className={cx(CSS.selectorList, choosing && "active")}>
          {mapObject(carts, (value, name) => (
            <a key={name} href={value} onClick={downloadCart}>
              {name}
            </a>
          ))}
        </div>

        <h3 className={CSS.prompt}>or</h3>
        <label className={CSS.upload}>
          <span>Upload a ROM</span>
          <input
            className={CSS.hidden}
            type="file"
            onChange={onFile}
            onClick={event => (event.currentTarget.value = "")}
          />
        </label>
      </div>
    </div>
  );
}
