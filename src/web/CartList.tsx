import React from "react";
import { useDropzone } from "react-dropzone";
import { useMemoryCache } from "./hooks/cache";
import * as DI from "./DI";
import { readAsArray } from "./promise";

export default function CartList({
  extra
}: {
  extra: Record<string, Uint8Array>;
}) {
  const { cart } = React.useContext(DI.Context);
  const cache = useMemoryCache<Uint8Array>("cartlist");
  const filePickerRef = React.useRef<HTMLInputElement>(null);

  const onDrop = React.useCallback(async (acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    const data = new Uint8Array(await readAsArray(file));
    cache.setItem(file.name, data);
    cart.set(data);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({ onDrop });

  return (
    <div>
      {Object.keys(extra).map(name => (
        <div key={name}>
          <button onClick={() => cart.set(extra[name])}>{name}</button>
        </div>
      ))}
      {Object.keys(cache.data).map(name => (
        <div key={name}>
          <button onClick={() => cart.set(cache.data[name])}>{name}</button>
        </div>
      ))}
      <div {...getRootProps()}>
        <input {...getInputProps()} ref={filePickerRef} />
        <button onClick={() => filePickerRef.current!.click()}>Add File</button>
      </div>
    </div>
  );
}
