import React from "react";
import { style } from "typestyle";

const CSS = {
  topright: style({
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

interface Props {
  show?: "topright";
  children: React.ReactNode;
}

interface State {
  toasts: Toast[];
  fatal: boolean;
}

export class Provider extends React.Component<Props, State> {
  constructor(props) {
    super(props);

    this.add = this.add.bind(this);
    this.error = this.error.bind(this);

    this.state = {
      toasts: [],
      fatal: false
    };
  }

  componentDidCatch(error: Error) {
    this.setState({ fatal: true });
    this.add({ title: "Fatal", body: error.message || error });
    console.error(error);
  }

  componentDidMount() {
    window.addEventListener("error", event => {
      this.error(event.message);
    });
    window.addEventListener("unhandledrejection", event => {
      this.error(event.reason);
    });
  }

  add(toast: Toast) {
    this.setState(({ toasts }) => ({
      toasts: [...toasts, toast]
    }));
  }

  error(err: Error | string) {
    this.add({ title: "Error", body: err.message || err });
  }

  render() {
    return (
      <Context.Provider
        value={{
          toasts: this.state.toasts,
          add: this.add
        }}
      >
        {this.props.show && (
          <div className={CSS[this.props.show]}>
            {this.state.toasts.map((toast, i) => (
              <div key={i} className={CSS.item}>
                <h3>{toast.title}</h3>
                <div>{toast.body}</div>
              </div>
            ))}
          </div>
        )}

        {!this.state.fatal && this.props.children}
      </Context.Provider>
    );
  }
}

export default { Context, Provider };
