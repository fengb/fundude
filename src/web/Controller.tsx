import React from "react";
import useEvent from "react-use/lib/useEvent";

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
    <div>
      {Object.entries(keys)
        .filter(([k, v]) => v)
        .map(([key, v]) => key)}
    </div>
  );
}
