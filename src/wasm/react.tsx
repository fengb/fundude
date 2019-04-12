import React from "react";
import FundudeWasm from ".";

interface Item {
  fd?: FundudeWasm;
}

interface Props {
  bootCart: Uint8Array;
  children: React.ReactNode;
}

export const Context = React.createContext<Item>({});

export class Provider extends React.Component<Props, Item> {
  constructor(props: Props) {
    super(props);
    this.state = {};
    FundudeWasm.boot(props.bootCart).then(fd => {
      this.setState({ fd });
      fd.addEventListener("programCounter", () => this.forceUpdate());
    });
  }

  render() {
    return (
      <Context.Provider value={{ ...this.state }}>
        {this.props.children}
      </Context.Provider>
    );
  }
}

export default { Context, Provider };
