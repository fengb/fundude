import React from "react";
import FundudeWasm from ".";

interface Item {
  fd: FundudeWasm;
  run: () => void;
  pause: () => void;
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

    this.state = {
      fd: new FundudeWasm(props.bootCart),
      isRunning: false
    };

    this.handleChange = this.handleChange.bind(this);
    this.run = this.run.bind(this);
    this.pause = this.pause.bind(this);
    this.spin = this.spin.bind(this);
  }

  componentDidMount() {
    this.run();
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
      return this.pause();
    }

    requestAnimationFrame(this.spin);
  }

  run() {
    if (!this.state.isRunning) {
      this.state.fd.changed.remove(this.handleChange);
      this.setState({ isRunning: true }, this.spin);
    }
  }

  pause() {
    if (this.state.isRunning) {
      this.state.fd.changed.add(this.handleChange);
      this.setState({ isRunning: false });
    }
  }

  render() {
    if (!this.state.fd) {
      return this.props.loading || null;
    }

    return (
      <Context.Provider
        value={{ fd: this.state.fd, run: this.run, pause: this.pause }}
      >
        {this.props.children}
      </Context.Provider>
    );
  }
}

export default { Context, Provider };
