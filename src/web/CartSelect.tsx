import React from "react";
import { style } from "typestyle";
import { useDropzone } from "react-dropzone";
import FD from "../wasm/react";
import { readAsArray } from "./promise";

const CSS = {
  root: style({}),
  loadCart: style({
    display: "block",
    boxSizing: "content-box",
    width: "350px",
    height: "14px",
    border: "none",
    padding: 0,
    background: "#d9d9d9",
    borderRadius: "4px 4px 0 0",
    cursor: "pointer",
    textAlign: "center"
  })
};

export default function CartList(props: { startName: string }) {
  const [name, setName] = React.useState(props.startName);
  const { fd } = React.useContext(FD.Context);
  const filePickerRef = React.useRef<HTMLInputElement>(null);

  const onDrop = React.useCallback(async (acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    const data = new Uint8Array(await readAsArray(file));
    fd.init(data);
    setName(file.name);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({ onDrop });

  return (
    <div className={CSS.root}>
      {/* {Object.keys(extra).map(name => (
        <div key={name}>
          <button onClick={() => fd.init(extra[name])}>{name}</button>
        </div>
      ))}
      {Object.keys(cache.data).map(name => (
        <div key={name}>
          <button onClick={() => fd.init(cache.data[name])}>{name}</button>
        </div>
      ))} */}
      <div {...getRootProps()}>
        <input {...getInputProps()} ref={filePickerRef} />
        <button
          className={CSS.loadCart}
          onClick={() => filePickerRef.current!.click()}
        >
          {name}
        </button>
      </div>
    </div>
  );
}
