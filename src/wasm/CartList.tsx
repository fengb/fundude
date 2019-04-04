import React from "react";
import { useMemoryCache } from "./hooks/cache";

export default function Files({
  extra
}: {
  extra: Record<string, Uint8Array>;
}) {
  const cache = useMemoryCache<string>("cartlist");
  return (
    <div>
      {Object.keys(cache.data).map(name => (
        <div key={name}>{name}</div>
      ))}
      <button onClick={() => cache.setItem("foo", "val")}>Add</button>
    </div>
  );
}
