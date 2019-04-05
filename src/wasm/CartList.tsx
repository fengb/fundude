import React, { useCallback } from "react";
import { useDropzone } from "react-dropzone";
import { useMemoryCache } from "./hooks/cache";

export default function CartList({
  extra
}: {
  extra: Record<string, Uint8Array>;
}) {
  const cache = useMemoryCache<string>("cartlist");
  const filePickerRef = React.useRef<HTMLInputElement>(null);

  const onDrop = useCallback((acceptedFiles: File[]) => {
    const update = {} as Record<string, string>;
    acceptedFiles.forEach(f => {
      update[f.name] = f.name;
    });
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
