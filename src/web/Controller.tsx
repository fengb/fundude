import React from "react";
import cx from "classnames";
import { style } from "typestyle";
import useEvent from "react-use/lib/useEvent";

const CSS = {
  root: style({}),

  dpad: {
    base: style({
      position: "relative",
      width: "60px",
      height: "60px"
    }),
    direction: style({
      position: "absolute",
      background: "#082A08",
      height: "33.3333%",
      width: "33.3333%",
      boxShadow: "inset 0 0 2px 2px #082A08",
      border: "none",

      $nest: {
        "&.pressed": { background: "white" }
      }
    }),
    up: style({ left: "33.3333%", top: 0 }),
    down: style({ left: "33.3333%", bottom: 0 }),
    left: style({ left: 0, top: "33.3333%" }),
    right: style({ right: 0, top: "33.3333%" })
  },

  buttons: style({
  })
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

type KeyState = typeof INITIAL_STATE;

const KEY_MAP: Record<string, keyof KeyState> = {
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
  Comma: "b",
  Period: "a"
};

const VALUE_MAP: Record<string, boolean> = {
  keydown: true,
  keyup: false
};

function keyReducer(state: KeyState, action: KeyboardEvent) {
  const key = KEY_MAP[action.code];
  const value = VALUE_MAP[action.type];
  if (key == undefined || value == undefined) {
    return state;
  }

  action.preventDefault();

  return { ...state, [key]: value };
}

export default function Controller() {
  const [keys, dispatchKeyEvent] = React.useReducer(keyReducer, INITIAL_STATE);

  useEvent("keydown", dispatchKeyEvent, window);
  useEvent("keyup", dispatchKeyEvent, window);

  return (
    <div className={CSS.root}>
      <div className={CSS.dpad.base}>
        <button
          className={cx(CSS.dpad.direction, CSS.dpad.up, {
            pressed: keys.up
          })}
        />
        <button
          className={cx(CSS.dpad.direction, CSS.dpad.down, {
            pressed: keys.down
          })}
        />
        <button
          className={cx(CSS.dpad.direction, CSS.dpad.left, {
            pressed: keys.left
          })}
        />
        <button
          className={cx(CSS.dpad.direction, CSS.dpad.right, {
            pressed: keys.right
          })}
        />
      </div>

      <div className={CSS.buttons}></div>
    </div>
  );
}
