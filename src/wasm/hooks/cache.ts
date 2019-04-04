import { useState } from "react";

export interface CacheHook<V> {
  data: Readonly<Record<string | symbol, V>>;
  setItem: (key: string, value: V) => any;
  setItems: (items: Record<string, V>) => any;
  removeItem: (key: string) => any;
  removeItems: (keys: string[]) => any;
  clear: () => any;
}

const MEMORY_STORE = {} as Record<string, Record<string, any>>;

export function useMemoryCache<V>(namespace: string | symbol): CacheHook<V> {
  // TS doesn't understand symbol indexing yet:
  //    https://github.com/Microsoft/TypeScript/issues/1863
  const nsCoerce = namespace as string;

  if (!MEMORY_STORE[nsCoerce]) {
    MEMORY_STORE[nsCoerce] = {};
  }

  const data = MEMORY_STORE[nsCoerce] as Record<string, V>;

  const [cacheBust, setCacheBust] = useState([data]);

  return {
    data,
    setItem(key: string, value: V) {
      data[key] = value;
      setCacheBust([data]);
    },
    setItems(items: Record<string, V>) {
      Object.assign(data, items);
      setCacheBust([data]);
    },
    removeItem(key: string) {
      delete data[key];
      setCacheBust([data]);
    },
    removeItems(keys: string[]) {
      for (const key of keys) {
        delete data[key];
      }
      setCacheBust([data]);
    },
    clear() {
      for (const key of Object.keys(data)) {
        delete data[key];
      }
      setCacheBust([data]);
    }
  };
}
