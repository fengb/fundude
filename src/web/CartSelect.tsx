import React from "react";
import classnames from "classnames";
import { style } from "typestyle";
import { useDropzone } from "react-dropzone";
import FD from "../wasm/react";
import { readAsArray } from "./promise";

const CSS = {
  root: style({
    position: "relative",
    width: "350px",
    height: "18px",
    zIndex: 1
  }),

  backdrop: style({
    position: "fixed",
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    background: "#000000",
    opacity: 0,
    transition: "300ms ease-in opacity",
    pointerEvents: "none",

    $nest: {
      "&.active": {
        pointerEvents: "initial",
        opacity: 0.8
      }
    }
  }),

  toggler: style({
    position: "absolute",
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
    height: "0",

    $nest: {
      "&.active": {
        height: "350px"
      }
    }
  })
};

function FileSelect(props: {
  className: string;
  onSelect: (name: string, data: Uint8Array) => any;
}) {
  const filePickerRef = React.useRef<HTMLInputElement>(null);

  const onDrop = React.useCallback(async (acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    const data = new Uint8Array(await readAsArray(file));
    props.onSelect(file.name, data);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({ onDrop });

  return (
    <div className={props.className} {...getRootProps()}>
      <input {...getInputProps()} ref={filePickerRef} />
      <button onClick={() => filePickerRef.current!.click()}>Upload</button>
      {isDragActive && <div>Drop file here!</div>}
    </div>
  );
}

export default function CartSelect(props: { startName: string }) {
  const { fd } = React.useContext(FD.Context);
  const [choosing, setChoosing] = React.useState(false);
  const [name, setName] = React.useState(props.startName);

  function handleSelect(name: string, data: Uint8Array) {
    fd.init(data);
    setName(name);
    setChoosing(false);
  }

  return (
    <div className={CSS.root}>
      <div
        className={classnames(CSS.backdrop, choosing && "active")}
        onClick={() => setChoosing(false)}
      />
      <button className={CSS.toggler} onClick={() => setChoosing(!choosing)}>
        {name}
      </button>

      <FileSelect
        className={classnames(CSS.selector, choosing && "active")}
        onSelect={handleSelect}
      />
    </div>
  );
}
