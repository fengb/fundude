import React from "react";
import FundudeWasm from ".";

interface Item {
  fd: FundudeWasm;
}

interface Props {
  loading?: React.ReactNode;
  bootCart: Uint8Array;
  children: React.ReactNode;
}

export const Context = React.createContext<Item>(null!);

export class Provider extends React.Component<Props, Partial<Item>> {
  constructor(props: Props) {
    super(props);
    this.state = {};
    FundudeWasm.boot(props.bootCart).then(fd => {
      Object.assign(window, { fd });
      this.setState({ fd });
      fd.addEventListener("programCounter", () => this.forceUpdate());
    });
  }

  render() {
    if (!this.state.fd) {
      return this.props.loading || null;
    }

    return (
      <Context.Provider value={{ fd: this.state.fd }}>
        {this.props.children}
      </Context.Provider>
    );
  }
}

export default { Context, Provider };
