import React from "react";
import { EMPTY, BOOTLOADER } from "./data";

interface StoreItem<T> {
  value: T;
  set: (value: T) => any;
}

interface Store {
  cart: StoreItem<Uint8Array>;
}

const INITIAL: Store = {
  cart: {
    value: EMPTY,
    set: () => {}
  }
};

export const Context = React.createContext(INITIAL);

export function Container({ children }: { children: React.ReactNode }) {
  const [cart, setCart] = React.useState(BOOTLOADER);
  const store: Store = {
    cart: { value: cart, set: setCart }
  };
  return <Context.Provider value={store}>{children}</Context.Provider>;
}
