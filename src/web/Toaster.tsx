import React from "react";
import { style } from "typestyle";

const CSS = {
  root: style({
    position: "fixed",
    right: 10,
    maxWidth: 200
  }),

  item: style({
    marginTop: 10,
    border: "1px solid black",
    padding: 10,
    borderRadius: 4
  })
};

interface Toast {
  title: string;
  body: React.ReactNode;
}

interface Toaster {
  toasts: Toast[];
  add: (toast: Toast) => any;
}

export const Context = React.createContext<Toaster>(null!);

export function Provider(props: { children: React.ReactNode }) {
  const [toasts, setToasts] = React.useState<Toast[]>([]);
  function add(toast: Toast) {
    setToasts([...toasts, toast]);
  }

  return (
    <Context.Provider value={{ toasts, add }}>
      {props.children}
    </Context.Provider>
  );
}

export function ShowAll() {
  const ctx = React.useContext(Context);
  return (
    <div className={CSS.root}>
      {ctx.toasts.map((toast, i) => (
        <div key={i} className={CSS.item}>
          <h3>{toast.title}</h3>
          <div>{toast.body}</div>
        </div>
      ))}
    </div>
  );
}

export default { Context, Provider, ShowAll };
