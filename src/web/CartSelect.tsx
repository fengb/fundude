import React from "react";
import classnames from "classnames";
import { style } from "typestyle";

import { mapObject } from "./smalldash";

import FD from "../wasm/react";
import Toaster from "./Toaster";
import { readAsArray } from "./promise";
import UploadBackdrop from "./UploadBackdrop";

import ROMS from "../roms";
import DEBUG_ROMS from "../roms/debug";

const CSS = {
  root: style({
    position: "relative",
    zIndex: 1,
    width: "350px",
    height: "18px"
  }),

  toggler: style({
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

    $nest: {
      "&:hover": {
        paddingTop: "4px"
      }
    }
  }),

  selector: style({
    position: "absolute",
    overflow: "hidden",
    top: "100%",
    width: "100%",
    background: "#ffffffd0",
    transition: "300ms ease-in-out height",
    padding: "0 10px",
    height: "0",

    $nest: {
      "&.active": {
        height: "350px"
      }
    }
  }),

  selectorList: style({
    display: "flex",
    flexDirection: "column"
  })
};

export default function CartSelect(props: {
  startName: string;
  debug?: boolean;
}) {
  const { fd } = React.useContext(FD.Context);
  const toaster = React.useContext(Toaster.Context);
  const [choosing, setChoosing] = React.useState(false);
  const [name, setName] = React.useState(props.startName);

  const selectCart = React.useCallback(
    (name: string, data: Uint8Array) => {
      try {
        fd.init(data);
        setName(name);
      } catch (e) {
        toaster.add({ title: "Fatal", body: e.message || e });
        throw e;
      } finally {
        setChoosing(false);
      }
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

  const onDrop = React.useCallback(async (acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    const data = new Uint8Array(await readAsArray(file));
    selectCart(file.name, data);
  }, []);

  const carts = props.debug ? DEBUG_ROMS.blargg : ROMS;

  return (
    <div className={CSS.root}>
      <button className={CSS.toggler} onClick={() => setChoosing(!choosing)}>
        {name}
      </button>

      <UploadBackdrop
        dropzone={{ onDrop, multiple: false }}
        clickBackdrop={() => setChoosing(false)}
        active={choosing}
      >
        {({ inputRef }) => (
          <div className={classnames(CSS.selector, choosing && "active")}>
            <div className={classnames(CSS.selectorList, choosing && "active")}>
              {mapObject(carts, (value, name) => (
                <a key={name} href={value} onClick={downloadCart}>
                  {name}
                </a>
              ))}
            </div>
            <button onClick={() => inputRef.current!.click()}>Upload</button>
          </div>
        )}
      </UploadBackdrop>
    </div>
  );
}
