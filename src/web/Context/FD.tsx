import React from "react";
import FundudeWasm from "../wasm";

interface Item {
  fd: FundudeWasm;
  cart: Uint8Array;
  programCounter: number;

  setCart: (cart: Uint8Array) => any;
}

export const Context = React.createContext<Item | undefined>(undefined);
export default Context;

export function Provider(props: {
  bootCart: Uint8Array;
  children: React.ReactNode;
}) {
  const [fd, setFd] = React.useState<FundudeWasm>();
  const [cart, setCart] = React.useState(props.bootCart);
  React.useEffect(() => {
    FundudeWasm.boot(props.bootCart).then(fd => {
      Object.assign(window, { fd });
      setFd(fd);
    });
    return () => fd && fd.dealloc();
  }, []);

  const item: Item | undefined = fd && {
    fd,
    cart,
    programCounter: fd.programCounter,

    setCart(cart) {
      fd.init(cart);
      setCart(cart);
    }
  };
  return <Context.Provider value={item}>{props.children}</Context.Provider>;
}
