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
}

interface State {
  fd: FundudeWasm;
}

const MAX_SKIP_MS = 5000;
const MHz = 4194304;

export const Context = React.createContext<Item>(null);

export class Provider extends React.Component<Props, State> {
  prevSpin?: number;
  raf?: number;
  interval?: number;

  constructor(props: Props) {
    super(props);

    this.state = {
      fd: FundudeWasm.create(props.bootCart),
    };

    Object.assign(window, { fd: this.state.fd });

    this.handleChange = this.handleChange.bind(this);
    this.run = this.run.bind(this);
    this.pause = this.pause.bind(this);
    this.main = this.main.bind(this);
    this.catchup = this.catchup.bind(this);
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

  spin(ts: DOMHighResTimeStamp) {
    // TODO: re-enable no-skip
    // this.state.fd.stepFrames(1);
    const elapsed = ts - this.prevSpin;
    this.state.fd.stepMs(elapsed);
    this.prevSpin = ts;

    if (this.state.fd.cpu().PC() === this.state.fd.breakpoint) {
      this.pause();
      return false;
    }

    return true;
  }

  main(ts: DOMHighResTimeStamp) {
    if (!this.prevSpin) {
      return;
    }

    if (this.spin(ts)) {
      this.raf = requestAnimationFrame(this.main);
    }
  }

  catchup() {
    if (!this.prevSpin) {
      clearInterval(this.interval);
      return;
    }

    const ts = performance.now();
    const elapsed = ts - this.prevSpin;
    if (elapsed > 200) {
      if (!this.spin(ts)) {
        clearInterval(this.interval);
      }
    }
  }

  run() {
    if (!this.prevSpin) {
      this.state.fd.changed.remove(this.handleChange);
      this.prevSpin = performance.now();

      this.raf = requestAnimationFrame(this.main);
      this.interval = setInterval(this.catchup, 1000);
    }
  }

  pause() {
    if (this.prevSpin) {
      this.state.fd.changed.add(this.handleChange);
      this.prevSpin = null;
      cancelAnimationFrame(this.raf);
      clearInterval(this.interval);
    }
  }

  render() {
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
