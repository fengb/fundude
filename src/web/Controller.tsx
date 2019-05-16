import React from "react";
import cx from "classnames";
import { style } from "typestyle";
import useEvent from "react-use/lib/useEvent";
import FundudeWasm, { Input } from "../wasm";

const CSS = {
  root: style({
    display: "flex",
    flex: "1",
    justifyContent: "space-between",
    alignItems: "center"
  }),

  button: style({
    display: "inline-block",
    background: "#082A08",
    boxShadow: "inset 0 0 2px 2px #082A08",
    border: "none",
    color: "white",
    fontFamily: "Helvetica, Arial, sans-serif",
    fontSize: "24px",

    $nest: {
      "&.pressed": {
        background: "white",
        color: "#082A08"
      }
    }
  }),

  dpad: {
    base: style({
      position: "relative",
      width: "90px",
      height: "90px"
    }),
    direction: style({
      position: "absolute",
      height: "33.3333%",
      width: "33.3333%"
    }),
    up: style({ left: "33.3333%", top: 0 }),
    down: style({ left: "33.3333%", bottom: 0 }),
    left: style({ left: 0, top: "33.3333%" }),
    right: style({ right: 0, top: "33.3333%" })
  },

  buttons: {
    base: style({}),
    a: style({ width: "40px", height: "40px", borderRadius: "100%" }),
    b: style({ width: "40px", height: "40px", borderRadius: "100%" }),
    select: style({ fontSize: "14px" }),
    start: style({ fontSize: "14px" })
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
  ArrowUp: "up",
  KeyD: "right",
  ArrowRight: "right",
  KeyS: "down",
  ArrowDown: "down",
  KeyA: "left",
  ArrowLeft: "left",

  KeyN: "select",
  KeyM: "start",
  Enter: "start",
  Comma: "b",
  Period: "a"
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
    setInputs(props.fd.inputPress(event.currentTarget.value as any));
  }

  function handleMouseLeave(event: React.MouseEvent<HTMLButtonElement>) {
    if (!clicking) {
      return;
    }
    setInputs(props.fd.inputRelease(event.currentTarget.value as any));
  }

  useEvent("mouseup", (event: React.MouseEvent<HTMLButtonElement>) => {
    setClicking(false);
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
    const input = KEY_MAP[event.code];
    if (input) {
      event.preventDefault();
      setInputs(props.fd.inputPress(input));
    }
  });
  useEvent("keyup", (event: KeyboardEvent) => {
    const input = KEY_MAP[event.code];
    if (input) {
      event.preventDefault();
      setInputs(props.fd.inputRelease(input));
    }
  });

  return (
    <div className={CSS.root}>
      <div className={CSS.dpad.base}>
        <button
          value="up"
          className={cx(CSS.button, CSS.dpad.direction, CSS.dpad.up, {
            pressed: inputs.up
          })}
          onMouseDown={handleMouseDown}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          onTouchStart={handleTouch}
          onTouchEnd={handleUntouch}
        />
        <button
          value="down"
          className={cx(CSS.button, CSS.dpad.direction, CSS.dpad.down, {
            pressed: inputs.down
          })}
          onMouseDown={handleMouseDown}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          onTouchStart={handleTouch}
          onTouchEnd={handleUntouch}
        />
        <button
          value="left"
          className={cx(CSS.button, CSS.dpad.direction, CSS.dpad.left, {
            pressed: inputs.left
          })}
          onMouseDown={handleMouseDown}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          onTouchStart={handleTouch}
          onTouchEnd={handleUntouch}
        />
        <button
          value="right"
          className={cx(CSS.button, CSS.dpad.direction, CSS.dpad.right, {
            pressed: inputs.right
          })}
          onMouseDown={handleMouseDown}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          onTouchStart={handleTouch}
          onTouchEnd={handleUntouch}
        />
      </div>

      <div className={CSS.buttons.base}>
        <button
          value="select"
          className={cx(CSS.button, CSS.buttons.select, {
            pressed: inputs.select
          })}
          onMouseDown={handleMouseDown}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          onTouchStart={handleTouch}
          onTouchEnd={handleUntouch}
        >
          Select
        </button>
        <button
          value="start"
          className={cx(CSS.button, CSS.buttons.start, {
            pressed: inputs.start
          })}
          onMouseDown={handleMouseDown}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          onTouchStart={handleTouch}
          onTouchEnd={handleUntouch}
        >
          Start
        </button>
      </div>

      <div className={CSS.buttons.base}>
        <button
          value="b"
          className={cx(CSS.button, CSS.buttons.b, { pressed: inputs.b })}
          onMouseDown={handleMouseDown}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          onTouchStart={handleTouch}
          onTouchEnd={handleUntouch}
        >
          B
        </button>
        <button
          value="a"
          className={cx(CSS.button, CSS.buttons.a, { pressed: inputs.a })}
          onMouseDown={handleMouseDown}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          onTouchStart={handleTouch}
          onTouchEnd={handleUntouch}
        >
          A
        </button>
      </div>
    </div>
  );
}
