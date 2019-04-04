import { useState } from "react";

export interface CacheHook<V> {
  data: Readonly<Record<string | symbol, V>>;
  setItem: (key: string, value: V) => any;
  removeItem: (key: string) => any;
  clear: () => any;
}

const MEMORY_STORE = {} as Record<string, Record<string, any>>;

export function useMemoryCache<V>(namespace: string | symbol): CacheHook<V> {
  const [cacheBust, setCacheBust] = useState(0);

  // TS doesn't understand symbol indexing yet:
  //    https://github.com/Microsoft/TypeScript/issues/1863
  const nsCoerce = namespace as string;

  if (!MEMORY_STORE[nsCoerce]) {
    MEMORY_STORE[nsCoerce] = {};
  }

  const data = MEMORY_STORE[nsCoerce] as Record<string, V>;

  return {
    data,
    setItem(key: string, value: V) {
      data[key] = value;
      setCacheBust(cacheBust + 1);
    },
    removeItem(key: string) {
      delete data[key];
      setCacheBust(cacheBust + 1);
    },
    clear() {
      for (const key of Object.keys(data)) {
        delete data[key];
      }
      setCacheBust(cacheBust + 1);
    }
  };
}
