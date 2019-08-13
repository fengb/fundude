import React from "react";
import cx from "classnames";
import useEvent from "react-use/lib/useEvent";

import nano from "./nano";

import FundudeWasm, { Input } from "../wasm";

const CSS = {
  root: nano.rule({
    display: "flex",
    flex: "1",
    justifyContent: "space-between",
    alignItems: "center",
    touchAction: "none"
  }),

  button: nano.rule({
    display: "inline-block",
    background: "#082A08",
    boxShadow: "inset 0 0 2px 2px #082A08",
    border: "none",
    color: "white",
    fontFamily: "Helvetica, Arial, sans-serif",
    fontSize: "24px",

    "&.pressed": {
      background: "white",
      color: "#082A08"
    }
  }),

  dpad: {
    base: nano.rule({
      position: "relative",
      width: "90px",
      height: "90px"
    }),
    direction: nano.rule({
      position: "absolute",
      height: "33.3333%",
      width: "33.3333%"
    }),
    up: nano.rule({ left: "33.3333%", top: 0 }),
    down: nano.rule({ left: "33.3333%", bottom: 0 }),
    left: nano.rule({ left: 0, top: "33.3333%" }),
    right: nano.rule({ right: 0, top: "33.3333%" })
  },

  buttons: {
    base: nano.rule({}),
    a: nano.rule({ width: "40px", height: "40px", borderRadius: "100%" }),
    b: nano.rule({ width: "40px", height: "40px", borderRadius: "100%" }),
    select: nano.rule({ fontSize: "14px" }),
    start: nano.rule({ fontSize: "14px" })
  }
};

const INITIAL_STATE = {
  up: false,
  down: false,
  left: false,
  right: false,

  select: false,
  start: false,
  a: false,
  b: false
};

const KEY_MAP: Record<string, Input> = {
  KeyW: "up",
  KeyD: "right",
  KeyS: "down",
  KeyA: "left",

  ArrowUp: "up",
  ArrowRight: "right",
  ArrowDown: "down",
  ArrowLeft: "left",

  Backspace: "select",
  Backslash: "select",
  Enter: "start",

  KeyN: "select",
  KeyM: "start",
  Comma: "b",
  Period: "a",

  KeyO: "select",
  KeyP: "start",
  BracketLeft: "b",
  BracketRight: "a"
};

export default function Controller(props: { fd: FundudeWasm }) {
  const [inputs, setInputs] = React.useState(INITIAL_STATE);
  const [clicking, setClicking] = React.useState(false);

  function handleMouseDown(event: React.MouseEvent<HTMLButtonElement>) {
    setClicking(true);
    setInputs(props.fd.inputPress(event.currentTarget.value as any));
  }

  function handleMouseEnter(event: React.MouseEvent<HTMLButtonElement>) {
    if (!clicking) {
      return;
    }
    event.currentTarget.focus();
    setInputs(props.fd.inputPress(event.currentTarget.value as any));
  }

  function handleMouseLeave(event: React.MouseEvent<HTMLButtonElement>) {
    if (!clicking) {
      return;
    }
    event.currentTarget.blur();
    setInputs(props.fd.inputRelease(event.currentTarget.value as any));
  }

  useEvent("mouseup", (event: React.MouseEvent<HTMLButtonElement>) => {
    if (!clicking) {
      return;
    }
    setClicking(false);
    event.currentTarget.blur();
    setInputs(props.fd.inputReleaseAll());
  });

  function handleTouch(event: React.TouchEvent<HTMLButtonElement>) {
    event.preventDefault();
    setInputs(props.fd.inputPress(event.currentTarget.value as any));
  }

  function handleUntouch(event: React.TouchEvent<HTMLButtonElement>) {
    event.preventDefault();
    setInputs(props.fd.inputRelease(event.currentTarget.value as any));
  }

  useEvent("keydown", (event: KeyboardEvent) => {
    if (event.target.nodeName == "INPUT") {
      return;
    }

    const input = KEY_MAP[event.code];
    if (input) {
      event.preventDefault();
      setInputs(props.fd.inputPress(input));
    }
  });
  useEvent("keyup", (event: KeyboardEvent) => {
    if (event.target.nodeName == "INPUT") {
      return;
    }

    const input = KEY_MAP[event.code];
    if (input) {
      event.preventDefault();
      setInputs(props.fd.inputRelease(input));
    }
  });

  function Button(props: {
    value: Input;
    className: string;
    children?: string;
  }) {
    return (
      <button
        value={props.value}
        className={cx(CSS.button, props.className, {
          pressed: inputs[props.value]
        })}
        onMouseDown={handleMouseDown}
        onMouseEnter={handleMouseEnter}
        onMouseLeave={handleMouseLeave}
        onTouchStart={handleTouch}
        onTouchEnd={handleUntouch}
      >
        {props.children}
      </button>
    );
  }

  return (
    <div className={CSS.root}>
      <div className={CSS.dpad.base}>
        <Button value="up" className={cx(CSS.dpad.direction, CSS.dpad.up)} />
        <Button
          value="down"
          className={cx(CSS.dpad.direction, CSS.dpad.down)}
        />
        <Button
          value="left"
          className={cx(CSS.dpad.direction, CSS.dpad.left)}
        />
        <Button
          value="right"
          className={cx(CSS.dpad.direction, CSS.dpad.right)}
        />
      </div>

      <div className={CSS.buttons.base}>
        <Button value="select" className={CSS.buttons.select}>
          Select
        </Button>
        <Button value="start" className={CSS.buttons.start}>
          Start
        </Button>
      </div>

      <div className={CSS.buttons.base}>
        <Button value="b" className={CSS.buttons.b}>
          B
        </Button>
        <Button value="a" className={CSS.buttons.a}>
          A
        </Button>
      </div>
    </div>
  );
}
