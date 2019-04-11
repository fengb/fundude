import React from "react";
import { useDropzone } from "react-dropzone";
import { useMemoryCache } from "./hooks/cache";
import FD from "./Context/FD";
import { readAsArray } from "./promise";

export default function CartList({
  extra
}: {
  extra: Record<string, Uint8Array>;
}) {
  const fd = React.useContext(FD);
  const cache = useMemoryCache<Uint8Array>("cartlist");
  const filePickerRef = React.useRef<HTMLInputElement>(null);

  const onDrop = React.useCallback(async (acceptedFiles: File[]) => {
    const file = acceptedFiles[0];
    const data = new Uint8Array(await readAsArray(file));
    cache.setItem(file.name, data);
    fd && fd.setCart(data);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({ onDrop });

  return (
    <div>
      {Object.keys(extra).map(name => (
        <div key={name}>
          <button onClick={() => fd && fd.setCart(extra[name])}>{name}</button>
        </div>
      ))}
      {Object.keys(cache.data).map(name => (
        <div key={name}>
          <button onClick={() => fd && fd.setCart(cache.data[name])}>
            {name}
          </button>
        </div>
      ))}
      <div {...getRootProps()}>
        <input {...getInputProps()} ref={filePickerRef} />
        <button onClick={() => filePickerRef.current!.click()}>Add File</button>
      </div>
    </div>
  );
}
