import React from "react";
import FundudeWasm from ".";

interface Item {
  fd: FundudeWasm;
  run: () => void;
  pause: () => void;
}

interface Props {
  autoBoot: boolean;
  bootCart: Uint8Array;
  children: React.ReactNode;
  onError?: (error: any) => any;
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

    Object.assign(window, { fd: this.state.fd });

    this.handleChange = this.handleChange.bind(this);
    this.run = this.run.bind(this);
    this.pause = this.pause.bind(this);
    this.spin = this.spin.bind(this);
  }

  componentDidMount() {
    if (this.props.autoBoot) {
      this.run();
    } else {
      this.state.fd.changed.add(this.handleChange);
    }
  }

  handleChange() {
    this.forceUpdate();
  }

  spin() {
    if (!this.state.isRunning) {
      return;
    }

    try {
      this.state.fd.stepFrame();
    } catch (e) {
      this.props.onError && this.props.onError(e);
      return;
    }

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
      return null;
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
