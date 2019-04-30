import React from "react";
import FundudeWasm from ".";

interface Item {
  fd: FundudeWasm;
  run: () => void;
  stop: () => void;
}

interface Props {
  loading?: React.ReactNode;
  bootCart: Uint8Array;
  children: React.ReactNode;
}

interface State {
  fd: FundudeWasm;
  isRunning: boolean;
}

export const Context = React.createContext<Item>(null!);

export class Provider extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);

    this.handleChange = this.handleChange.bind(this);
    this.run = this.run.bind(this);
    this.stop = this.stop.bind(this);
    this.spin = this.spin.bind(this);

    const fd = new FundudeWasm(props.bootCart);
    fd.changed.add(this.handleChange);

    this.state = { fd, isRunning: false };
  }

  handleChange() {
    if (!this.state.isRunning) {
      this.forceUpdate();
    }
  }

  spin() {
    if (!this.state.isRunning) {
      return;
    }

    this.state.fd.stepFrame();
    if (this.state.fd.cpu().PC() === this.state.fd.breakpoint) {
      return this.stop();
    }

    requestAnimationFrame(this.spin);
  }

  run() {
    if (!this.state.isRunning) {
      this.setState({ isRunning: true }, this.spin);
    }
  }

  stop() {
    this.setState({ isRunning: false });
  }

  render() {
    if (!this.state.fd) {
      return this.props.loading || null;
    }

    return (
      <Context.Provider
        value={{ fd: this.state.fd, run: this.run, stop: this.stop }}
      >
        {this.props.children}
      </Context.Provider>
    );
  }
}

export default { Context, Provider };
