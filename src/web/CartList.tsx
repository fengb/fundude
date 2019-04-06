import React from "react";
import { useDropzone } from "react-dropzone";
import { useMemoryCache } from "./hooks/cache";
import { Context } from "./DI";
import { readAsArray } from "./promise";

export default function CartList({
  extra
}: {
  extra: Record<string, Uint8Array>;
}) {
  const { cart } = React.useContext(Context);
  const cache = useMemoryCache<string>("cartlist");
  const filePickerRef = React.useRef<HTMLInputElement>(null);

  const onDrop = React.useCallback((acceptedFiles: File[]) => {
    const update = {} as Record<string, string>;
    for (const file of acceptedFiles) {
      update[file.name] = file.name;
      readAsArray(file).then(buf => cart.set(new Uint8Array(buf)));
    }
    cache.setItems(update);
  }, []);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({ onDrop });

  return (
    <div>
      {Object.keys(extra).map(name => (
        <div key={name}>{name}</div>
      ))}
      {Object.keys(cache.data).map(name => (
        <div key={name}>{name}</div>
      ))}
      <div {...getRootProps()}>
        <input {...getInputProps()} ref={filePickerRef} />
        <button onClick={() => filePickerRef.current!.click()}>Add File</button>
      </div>
    </div>
  );
}
